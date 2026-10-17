# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

require_relative '../../support/reclassification_fixture'

class ReclassificationCommitTest < ActiveSupport::TestCase
  include ReclassificationFixture

  test 'preview is read only and does not authorize execution' do
    before = @record.reload.attributes
    identity = VideoAssets::RelocationFileIdentity.call(File.lstat(@source))
    assert @plan[:ready]
    assert_equal false, @plan[:execution_authorized]
    assert_equal before, @record.reload.attributes
    assert_equal identity, VideoAssets::RelocationFileIdentity.call(File.lstat(@source))
    assert_not File.exist?(@target)
    assert_not File.exist?(File.join(@root, 'journal'))
  end

  test 'commit atomically updates genres provenance and path preserving other metadata' do
    result = execute
    assert_equal :completed, result[:status]
    assert_equal @target, @asset.reload.last_known_path
    assert_equal [@new.name], @record.reload.genders.map(&:name)
    assert_equal 'documented_review', @record.genre_provenance['origin']
    assert_equal 'fixture', @asset.technical_details.dig('language_qualification', 'basis')
    assert_equal 'fixture', File.binread(@target)
    assert_equal @plan[:identity][:ino], File.lstat(@target).ino
    assert_not File.exist?(@source)
  end

  test 'journal contains the complete proposal and snapshots needed for reconciliation' do
    execute
    rows = journal
    assert_equal %w[prepared filesystem_renamed completed], rows.map { |row| row['event'] }
    assert_equal [@new.name], rows.first.dig('classification', 'genres')
    assert_equal @qualification[:record_snapshot], rows.first.dig('qualification', 'record_snapshot')
    assert_equal @qualification[:copy_snapshot], rows.first.dig('qualification', 'copy_snapshot')
    assert_equal 'reclassification-fixture', rows.first.dig('qualification', 'operation_id')
  end

  test 'documentary classification uses the documentary branch' do
    documentary = Gender.find_by(name: 'Documentaire')
    unless documentary
      documentary = Gender.create!(name: 'Documentaire')
      @owned_genres << documentary
    end
    configure(category: 'documentary', genres: ['Documentaire'])
    execute
    assert_equal File.join(@root, 'Documentaires', 'Reclassification test (2000).mkv'), @asset.reload.last_known_path
    assert_equal ['Documentaire'], @record.reload.genders.map(&:name)
  end

  test 'no execution authorization means no journal no movement and no database write' do
    assert_raises(VideoAssets::RelocationCommit::Refused) { execute(authorized: false) }
    assert File.exist?(@source)
    assert_not File.exist?(@target)
    assert_not File.exist?(File.join(@root, 'journal'))
  end

  test 'a changed synopsis is refused before moving the file' do
    @record.update!(abstract: 'Manual correction')
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
    assert_equal 'Manual correction', @record.reload.abstract
  end

  test 'a changed language proof is refused before moving the file' do
    @asset.update!(technical_details: { 'language_qualification' => { 'basis' => 'new' } })
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
    assert_equal 'new', @asset.reload.technical_details.dig('language_qualification', 'basis')
  end

  test 'manual genre edits stay protected' do
    @record.genders = [@new]
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
    assert_equal 'manual_or_untracked', @record.reload.genre_provenance['origin']
  end

  test 'destination occupied after preview is never overwritten' do
    File.write(@target, 'keep')
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert_equal 'keep', File.read(@target)
    assert File.exist?(@source)
  end

  test 'a destination claimed even by a deleted copy is refused' do
    other = VideoAsset.create!(record: @record, status: 'deleted', last_known_path: @target)
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
    assert_equal @target, other.reload.last_known_path
  end

  test 'native failure leaves genres provenance path and source unchanged' do
    @renamer = ->(**_args) { raise Errno::EACCES }
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal [@old.name], @record.reload.genders.map(&:name)
    assert_equal({}, @record.genre_provenance)
    assert File.exist?(@source)
    assert_equal %w[prepared needs_review], journal.map { |row| row['event'] }
  end

  test 'SQL failure rolls back both SQL changes while retaining the moved file and journal' do
    @asset.define_singleton_method(:update!) { |**_args| raise ActiveRecord::RecordInvalid.new(self) }
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal [@old.name], @record.reload.genders.map(&:name)
    assert_equal({}, @record.genre_provenance)
    assert File.exist?(@target)
    assert_not File.exist?(@source)
    assert_equal %w[prepared filesystem_renamed needs_review], journal.map { |row| row['event'] }
  end

  test 'an existing journal blocks a blind second execution' do
    execute
    before = journal
    assert_raises(Errno::EEXIST) { execute }
    assert_equal before, journal
    assert_equal @target, @asset.reload.last_known_path
  end

  test 'new JSON dependency blocks a plan before native rename' do
    File.write(@source.sub(/\.mkv\z/, '.json'), '{}')
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
  end

  test 'same directory keeps the separate original planner contract' do
    original = VideoAssets::RelocationPlanner.new(root: @root, volume_guard: @guard)
    original_plan = original.call(asset: @asset, genres: [@old.name])
    assert original_plan[:ready]
    assert original_plan[:checks][:same_directory]
    assert_not @plan[:checks].key?(:same_directory)
    assert @plan[:checks][:different_directories]
  end
  test 'source identity changes after preview block the operation' do
    File.write(@source, 'changed')
    older = Time.at(@plan[:identity][:mtime_ns] / 1_000_000_000) - 1
    File.utime(older, older, @source)
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert_equal 'changed', File.read(@source)
    assert_equal @source, @asset.reload.last_known_path
  end

  test 'missing destination directory is not created implicitly' do
    Dir.rmdir(File.dirname(@target))
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert_not File.exist?(File.dirname(@target))
    assert File.exist?(@source)
  end

  test 'volume guard failure prevents even journal preparation' do
    @guard = -> { raise ArgumentError, 'Wrong volume' }
    assert_raises(ArgumentError) { execute }
    assert File.exist?(@source)
    assert_not File.exist?(File.join(@root, 'journal'))
  end

  test 'a mismatched expected genre snapshot is rejected before movement' do
    @qualification[:expected][:genres] = ['WRONG']
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    assert File.exist?(@source)
    assert_equal({}, @record.reload.genre_provenance)
  end

  test 'completion journal failure leaves the committed state available for reconciliation' do
    append = VideoAssets::RelocationJournal.method(:append)
    interrupted = lambda do |file, event, details = {}|
      raise IOError, 'Completion fixture' if event == 'completed'

      append.call(file, event, details)
    end
    VideoAssets::RelocationJournal.stub(:append, interrupted) do
      assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    end
    assert_equal @target, @asset.reload.last_known_path
    assert_equal [@new.name], @record.reload.genders.map(&:name)
    assert_equal 'reclassification-fixture', @record.genre_provenance['operation_id']
    assert File.exist?(@target)
    assert_not File.exist?(@source)
    assert_equal %w[prepared filesystem_renamed needs_review], journal.map { |row| row['event'] }
  end
end
