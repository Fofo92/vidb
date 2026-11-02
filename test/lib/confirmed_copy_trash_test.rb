# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'ostruct'
require_relative '../../lib/confirmed_copy_trash'

class ConfirmedCopyTrashTest < ActiveSupport::TestCase
  class Database
    attr_reader :locked
    attr_accessor :jobs

    def initialize
      @jobs = []
    end

    def transaction(mode:)
      raise 'Wrong lock' unless mode == :immediate
      @locked = true
      yield
    ensure
      @locked = false
    end

    def [](name)
      raise 'Wrong table' unless name == :jobs
      self
    end

    def where(status:)
      @jobs.select { |row| status.include?(row[:status]) }
    end
  end

  setup do
    @root = Dir.mktmpdir
    @path = File.join(@root, 'Copie française.m4v')
    File.write(@path, 'video')
    @database = Database.new
    @roots = []
    @registry = Object.new
    roots = @roots
    @registry.define_singleton_method(:add) { |root| roots << root }
    @used = []
    database, used = @database, @used
    @usage = Object.new
    @usage.define_singleton_method(:validate) do |entry|
      raise 'Missing queue lock' unless database.locked
      raise ConfirmedCopyTrash::Error, 'Copie utilisée.' if (entry.entries.keys & used).any?
    end
    @operation = ConfirmedCopyTrash::Operation.new(database: @database, registry: @registry,
                                                  usage: @usage, root: @root)
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test 'preview only reads the file and checks queue usage under the lock' do
    result = preview
    assert_equal @path, result['path']
    assert_equal 'video', File.read(@path)
    assert_equal [], @roots
    assert_not File.exist?(File.join(@root, '.video_encoder_trash'))
  end

  test 'move only the selected media and create a compatible one-file trash manifest' do
    project = File.join(@root, 'Copie française.json')
    other = File.join(@root, 'Autre copie.mkv')
    File.write(project, 'project')
    File.write(other, 'other')
    result = remove
    assert_not File.exist?(@path)
    assert_equal 'video', File.read(result['archived'])
    assert_equal({ @path => result['archived'] }, JSON.parse(File.read(File.join(result['directory'], 'manifest.json'))))
    assert_equal 'project', File.read(project)
    assert_equal 'other', File.read(other)
    assert_includes @roots, File.join(@root, '.video_encoder_trash')
  end

  test 'repeating the same request returns the same receipt without moving another file' do
    request = removal_request
    first = @operation.call(request)
    assert_equal first, @operation.call(request)
    assert_equal 1, Dir.children(File.dirname(first['directory'])).size
  end

  test 'a changed file is refused after confirmation' do
    request = removal_request
    File.write(@path, 'changed')
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert_equal 'changed', File.read(@path)
  end

  test 'an active reference appearing after preview prevents the move' do
    request = removal_request
    @used << @path
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert File.exist?(@path)
    assert_not File.exist?(File.join(@root, '.video_encoder_trash'))
  end

  test 'an inaccessible active project blocks a move without claiming that its sources are safe' do
    request = removal_request
    @database.jobs = [{ status: 'running', project_path: File.join(@root, 'missing.json') }]
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert File.exist?(@path)
  end

  test 'finished jobs with missing projects do not prevent removal' do
    @database.jobs = [{ status: 'succeeded', project_path: File.join(@root, 'missing.json') }]
    assert File.file?(remove['archived'])
  end

  test 'symbolic media and hard links are refused' do
    alias_path = File.join(@root, 'alias.m4v')
    File.symlink(@path, alias_path)
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call('operation' => 'preview', 'path' => alias_path) }
    File.unlink(alias_path)
    File.link(@path, alias_path)
    assert_raises(ConfirmedCopyTrash::Error) { preview }
  end

  test 'symbolic parent directories are refused' do
    File.symlink(@root, File.join(@root, 'alias'))
    assert_raises(ConfirmedCopyTrash::Error) do
      @operation.call('operation' => 'preview', 'path' => File.join(@root, 'alias', File.basename(@path)))
    end
  end

  test 'JSON files and files outside the video root are refused' do
    assert_raises(ConfirmedCopyTrash::Error) do
      @operation.call('operation' => 'preview', 'path' => File.join(@root, 'project.json'))
    end
    assert_raises(ConfirmedCopyTrash::Error) do
      @operation.call('operation' => 'preview', 'path' => '/tmp/unrelated.mkv')
    end
  end

  test 'a symbolic trash root is refused without moving the file' do
    request = removal_request
    File.symlink(@root, File.join(@root, '.video_encoder_trash'))
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert File.exist?(@path)
  end

  test 'an existing different archive is never overwritten' do
    request = removal_request
    first = @operation.call(request)
    File.write(@path, 'new video')
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert_equal 'video', File.read(first['archived'])
    assert_equal 'new video', File.read(@path)
  end

  test 'a tampered manifest prevents resuming' do
    request = removal_request
    receipt = @operation.call(request)
    File.write(File.join(receipt['directory'], 'manifest.json'), '{}')
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert_equal 'video', File.read(receipt['archived'])
  end

  test 'invalid operation identifiers cannot escape the trash directory' do
    request = removal_request.merge('id' => '../other')
    assert_raises(ConfirmedCopyTrash::Error) { @operation.call(request) }
    assert File.exist?(@path)
  end

  private

  def preview
    @operation.call('operation' => 'preview', 'path' => @path)
  end

  def removal_request
    preview.merge('operation' => 'remove', 'id' => SecureRandom.uuid)
  end

  def remove
    @operation.call(removal_request)
  end
end
