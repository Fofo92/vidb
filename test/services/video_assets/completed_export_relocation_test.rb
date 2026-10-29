require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'minitest/mock'

class CompletedExportRelocationTest < ActiveSupport::TestCase
  Asset = Struct.new(:id, :record_id, :status, :last_known_path, :byte_size, :technical_details, :observed_at,
                     keyword_init: true) do
    def status_present?
      status == 'present'
    end

    def update!(attributes)
      attributes.each { |name, value| public_send("#{name}=", value) }
    end
  end

  class Scope < Array
    def lock
      self
    end
  end

  setup do
    @directory = Dir.mktmpdir
    @old = File.join(@directory, 'Ancien.mkv')
    @new = File.join(@directory, 'Nouveau : A & B.mkv')
    File.write(@new, 'video')
    @record = Struct.new(:id).new(42)
    @receipt = { 'format' => 'video_encoder.completed_export', 'version' => 1,
                 'project_id' => 'stable-project', 'project_sha256' => 'a' * 64,
                 'output_path' => @old, 'project_path' => @old.sub('.mkv', '.json'),
                 'completed_at' => '2026-10-29T00:00:00Z', 'byte_size' => 5,
                 'modified_at' => '2026-10-28T23:59:00Z', 'roles' => ['french'],
                 'probe' => { 'format' => { 'filename' => @old, 'duration' => '2400' }, 'streams' => [] } }
    @asset = Asset.new(id: 123, record_id: 42, status: 'missing', last_known_path: @old, byte_size: 5,
                       technical_details: { 'video_encoder_export' => @receipt.deep_dup,
                                            'manual_note' => 'Conserver', 'disk_presence_history' => ['history'] })
    @assets = [@asset]
    @moved = @receipt.deep_dup
    @moved.merge!('previous_output_path' => @old, 'output_path' => @new,
                  'project_path' => @new.sub('.mkv', '.json'))
    @moved['probe']['format']['filename'] = @new
  end

  teardown { FileUtils.remove_entry(@directory) }

  def relocate
    finder = lambda do |**conditions|
      Scope.new(@assets.select do |asset|
        conditions.all? { |key, value| Array(value).include?(asset.public_send(key)) }
      end)
    end
    VideoAsset.stub(:where, finder) do
      VideoAssets::CompletedExportRelocation.new(@record, { path: @new },
                                                 { receipt: @moved, details: @moved['probe'] }).call
    end
  end

  test 'updates the same asset and preserves its technical history' do
    result = relocate
    assert_equal 'relocated', result[:status]
    assert_equal 123, result[:video_asset_id]
    assert_equal @new, @asset.last_known_path
    assert_equal 'present', @asset.status
    assert_equal 'Conserver', @asset.technical_details['manual_note']
    assert_equal ['history'], @asset.technical_details['disk_presence_history']
    assert_equal @old, @asset.technical_details['relocation_history'].sole['from']
    assert_equal @receipt, @asset.technical_details['relocation_history'].sole['previous_receipt']
    assert_equal @moved, @asset.technical_details['video_encoder_export']
  end

  test 'also restores a copy not yet marked missing by the scan' do
    @asset.status = 'present'
    assert_equal 'relocated', relocate[:status]
  end

  test 'an old file still present is a second copy rather than a relocation' do
    File.write(@old, 'video')
    assert_nil relocate
    assert_equal @old, @asset.last_known_path
  end

  test 'a dangling symlink is not treated as an absent old file' do
    File.symlink(File.join(@directory, 'absent'), @old)
    assert_nil relocate
  end

  test 'without relocation evidence the normal import remains in charge' do
    @moved.delete('previous_output_path')
    assert_nil relocate
  end

  test 'without a known old asset the normal import remains in charge' do
    @assets.clear
    assert_nil relocate
  end

  test 'successive moves before a scan find the last registered path by receipt identity' do
    @moved['previous_output_path'] = File.join(@directory, 'Intermediaire.mkv')
    assert_equal 'relocated', relocate[:status]
    assert_equal @old, @asset.technical_details['relocation_history'].sole['from']
  end

  test 'a project path normalization may change its hash when the project identity is stable' do
    @moved['project_sha256'] = 'b' * 64
    assert_equal 'relocated', relocate[:status]
  end

  test 'a changed project hash without stable identity is refused' do
    @moved.delete('project_id')
    @asset.technical_details['video_encoder_export'].delete('project_id')
    @moved['project_sha256'] = 'b' * 64
    assert_raises(ArgumentError) { relocate }
  end

  test 'a legacy receipt with an unchanged hash is supported' do
    @moved.delete('project_id')
    @asset.technical_details['video_encoder_export'].delete('project_id')
    assert_equal 'relocated', relocate[:status]
  end

  test 'changed export evidence is never merged' do
    ['completed_at', 'byte_size', 'roles', 'project_id'].each do |key|
      previous = @moved[key]
      @moved[key] = 'different'
      assert_raises(ArgumentError, key) { relocate }
      assert_equal @old, @asset.last_known_path
      @moved[key] = previous
    end
  end

  test 'a deleted copy or a copy belonging to another work is not moved' do
    @asset.status = 'deleted'
    assert_raises(ArgumentError) { relocate }
    @asset.status = 'missing'
    @asset.record_id = 99
    assert_raises(ArgumentError) { relocate }
  end

  test 'multiple possible old assets require review' do
    @assets << @asset.dup
    assert_raises(ArgumentError) { relocate }
  end

  test 'invalid previous paths never change the registered copy' do
    ['relative.mkv', "#{@directory}/../Ancien.mkv", @new, "bad\0path"].each do |path|
      @moved['previous_output_path'] = path
      assert_raises(ArgumentError) { relocate }
      assert_equal @old, @asset.last_known_path
    end
  end

  test 'the import pipeline relocates then recognizes the same export without creating an asset' do
    @record.define_singleton_method(:lock!) { nil }
    @record.define_singleton_method(:parent) { nil }
    @record.define_singleton_method(:children) { [] }
    @record.define_singleton_method(:hierarchy_placement_status) { :consistent }
    @record.define_singleton_method(:record_kind_standalone_video?) { true }
    fields = { ancestry: nil, rank: nil, french_title: 'Film', original_title: '' }
    fields.each { |key, value| @record.define_singleton_method(key) { value } }
    observation = { path: @new, candidates: [fields.merge(record_id: @record.id)] }
    stat = File.stat(@new)
    export = { receipt: @moved, details: @moved['probe'], signature: [stat.size, stat.mtime, stat.ino] }
    connection = Struct.new(:adapter_name).new('SQLite')
    scope = ->(**conditions) { Scope.new(@assets.select { |asset| conditions.all? { |k, v| Array(v).include?(asset[k]) } }) }
    find_path = ->(**conditions) { @assets.find { |asset| asset.last_known_path == conditions[:last_known_path] } }
    Record.stub(:transaction, ->(&block) { block.call }) do
      Record.stub(:connection, connection) do
        Record.stub(:find, @record) do
          VideoAsset.stub(:where, scope) do
            VideoAsset.stub(:find_by, find_path) do
              importer = VideoAssets::CompletedExportImport.new(observation, export)
              assert_equal 'relocated', importer.call[:status]
              assert_equal 'already_imported', importer.call[:status]
              assert_equal 1, @asset.technical_details['relocation_history'].size
            end
          end
        end
      end
    end
  end
end
