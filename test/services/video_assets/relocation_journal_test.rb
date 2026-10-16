# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

class RelocationJournalTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @directory = File.join(@root, 'journals')
    @asset = Struct.new(:record_id, :id).new(2, 1)
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test 'creates a private journal and preserves prior evidence on retry' do
    path = nil
    journal.open(@asset) do |file|
      path = file.path
      VideoAssets::RelocationJournal.append(file, 'prepared', source: '/tmp/fixture')
    end
    assert_equal 0o700, File.stat(@directory).mode & 0o777
    assert_equal 0o600, File.stat(path).mode & 0o777
    content = File.binread(path)
    assert_equal 'prepared', JSON.parse(content)['event']
    assert_raises(Errno::EEXIST) { journal.open(@asset) { flunk 'Existing journal must not be reused' } }
    assert_equal content, File.binread(path)
  end

  test 'refuses shared journal directories' do
    Dir.mkdir(@directory, 0o755)
    assert_raises(ArgumentError) { journal.open(@asset) { flunk } }
    assert_empty Dir.children(@directory)
  end

  test 'refuses a journal directory symlink' do
    actual = File.join(@root, 'actual')
    Dir.mkdir(actual, 0o700)
    File.symlink(actual, @directory)
    assert_raises(ArgumentError) { journal.open(@asset) { flunk } }
    assert_empty Dir.children(actual)
  end

  private

  def journal
    VideoAssets::RelocationJournal.new(@directory)
  end
end
