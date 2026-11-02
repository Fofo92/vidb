require 'test_helper'
require 'tmpdir'

class MissingCopyRetirementTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    @user = User.create!(email: 'retirement@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'RET', long_name: 'Version test')
    @record = Record.create!(french_title: 'Terreurs', record_kind: 'standalone_video', language_version: language)
    @old = @record.video_assets.create!(status: 'missing', last_known_path: File.join(@root, 'old_vf.mkv'),
                                        duration_minutes: 42, technical_details: { 'qualification' => 'keep' })
    @current = @record.video_assets.create!(status: 'present', last_known_path: File.join(@root, 'current.mkv'),
                                            duration_minutes: 42)
    File.write(@current.last_known_path, 'current encoding')
    @backup = VideoAssets::CopyReferenceBackup.new(directory: File.join(@root, 'backups'))
    @service = VideoAssets::MissingCopyRetirement.new(user: @user, root: @root, guard: -> {}, backup: @backup)
  end

  teardown { FileUtils.remove_entry(@root) }

  def token(*assets)
    @service.confirmation(assets.map(&:id)).fetch(:token)
  end

  test 'confirmation does not change the reference or files' do
    assert token(@old).present?
    assert @old.reload.status_missing?
    assert_equal ['current.mkv'], Dir.children(@root)
  end

  test 'cleanup backs up the obsolete reference and preserves the present copy and viewing state' do
    @record.update_columns(is_seen: true)
    @service.call(token(@old))
    assert_not VideoAsset.exists?(@old.id)
    data = VideoAssets::CopyReferenceBackup.read(@service.backup_path)
    assert_equal 'keep', data['assets'].first.dig('technical_details', 'qualification')
    assert_equal @user.id, data['user_id']
    assert_equal 1, @record.video_assets.count
    assert @record.reload.is_seen
    assert @record.reload.is_recorded
    assert @record.is_available
    assert @current.reload.status_present?
    assert_equal 'current encoding', File.read(@current.last_known_path)
    assert_equal ['backups', 'current.mkv'], Dir.children(@root).sort
  end

  test 'present copies cannot be cleaned but old deleted references can' do
    assert_raises(ArgumentError) { token(@current) }
    @old.update!(status: 'deleted')
    @service.call(token(@old))
    assert_not VideoAsset.exists?(@old.id)
  end

  test 'reappearing file prevents confirmation even before the next inventory' do
    confirmation = token(@old)
    File.write(@old.last_known_path, 'reappeared')
    assert_raises(ArgumentError) { @service.call(confirmation) }
    assert @old.reload.status_missing?
    assert_equal 'reappeared', File.read(@old.last_known_path)
  end

  test 'a changed reference invalidates the signed plan' do
    confirmation = token(@old)
    @old.update!(last_known_path: File.join(@root, 'renamed.mkv'))
    assert_raises(ArgumentError) { @service.call(confirmation) }
    assert @old.reload.status_missing?
  end

  test 'a batch is all or nothing when one file reappears' do
    other = @record.video_assets.create!(status: 'missing', last_known_path: File.join(@root, 'other.mkv'))
    confirmation = token(@old, other)
    File.write(other.last_known_path, 'keep')
    assert_raises(ArgumentError) { @service.call(confirmation) }
    assert @old.reload.status_missing?
    assert other.reload.status_missing?
  end

  test 'batch updates all selected references and none of the present copies' do
    other = @record.video_assets.create!(status: 'missing', last_known_path: File.join(@root, 'other.mkv'))
    result = @service.call(token(@old, other))
    assert_equal [@old.id, other.id], result.map(&:id)
    assert_not VideoAsset.exists?(@old.id)
    assert_not VideoAsset.exists?(other.id)
    assert @current.reload.status_present?
  end

  test 'invalid expired and wrong user tokens cannot change references' do
    assert_raises(ArgumentError) { @service.call('invalid') }
    confirmation = token(@old)
    travel 16.minutes do
      assert_raises(ArgumentError) { @service.call(confirmation) }
    end
    service = VideoAssets::MissingCopyRetirement.new(user: Struct.new(:id).new(@user.id + 1), root: @root, guard: -> {}, backup: @backup)
    assert_raises(ArgumentError) { service.call(confirmation) }
    assert @old.reload.status_missing?
  end

  test 'an in-progress trash operation must be resumed rather than retired' do
    @old.update!(technical_details: { 'copy_removal_pending' => { 'id' => 'pending' } })
    assert_raises(ArgumentError) { token(@old) }
  end

  test 'loss of the mounted volume rolls back the entire transaction' do
    confirmation = token(@old)
    count = 0
    guard = -> { count += 1; raise ArgumentError, 'Volume lost' if count == 2 }
    service = VideoAssets::MissingCopyRetirement.new(user: @user, root: @root, guard: guard, backup: @backup)
    assert_raises(ArgumentError) { service.call(confirmation) }
    assert @old.reload.status_missing?
  end

  test 'the production default constructs its volume guard with the required root' do
    assert_instance_of VideoAssets::MissingCopyRetirement, VideoAssets::MissingCopyRetirement.new(user: @user)
  end

  test 'empty excessive or invalid selections are refused' do
    [[], (1..101).to_a, ['invalid']].each do |ids|
      assert_raises(ArgumentError) { @service.confirmation(ids) }
    end
  end

  test 'backup failure prevents every removal' do
    failed = Object.new
    failed.define_singleton_method(:write) { |*_args, **_options| raise Errno::ENOSPC }
    service = VideoAssets::MissingCopyRetirement.new(user: @user, root: @root, guard: -> {}, backup: failed)
    assert_raises(Errno::ENOSPC) { service.call(token(@old)) }
    assert @old.reload.status_missing?
    assert @current.reload.status_present?
  end

  test 'old retirement confirmations cannot authorize physical reference cleanup' do
    plan = { 'user_id' => @user.id, 'copies' => [] }
    previous = Rails.application.message_verifier('missing-copy-retirement').generate(
      plan, purpose: 'missing-copy-retirement', expires_in: 15.minutes
    )
    assert_raises(ArgumentError) { @service.call(previous) }
    assert @old.reload.status_missing?
  end

  test 'viewing states including unknown survive removal of the final copy' do
    @current.destroy!
    [true, false, nil].each_with_index do |seen, index|
      copy = @record.video_assets.create!(status: 'missing', last_known_path: File.join(@root, "gone#{index}.mkv"))
      @record.update_columns(is_seen: seen, seen_state_confirmed_at: Time.current)
      before = @record.reload.attributes.slice('is_seen', 'seen_state_confirmed_at')
      @service.call(token(copy))
      assert_equal before, @record.reload.attributes.slice('is_seen', 'seen_state_confirmed_at')
    end
  end
end
