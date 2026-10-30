require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'active_support/cache'

class Tv::CaptureEpisodeAcquisitionsTest < ActiveSupport::TestCase
  Programme = Struct.new(:id, :titles, :episode_numbers, :subtitles)

  def programme
    Programme.new(7, [{ 'value' => 'Joséphine, ange gardien', 'language' => 'fr' }],
                  [{ 'system' => 'xmltv_ns', 'value' => '11.10.' }],
                  [{ 'value' => 'Chasse aux fantômes', 'language' => 'fr' }])
  end

  test 'finds the source after quarantine and expires its old cached path' do
    Dir.mktmpdir do |root|
      captures = File.join(root, 'captures')
      quarantine = File.join(root, 'quarantine')
      FileUtils.mkdir_p([captures, quarantine])
      name = 'Joséphine, ange gardien - S12 E11 - Chasse aux fantômes.m2t'
      source = File.join(captures, name)
      File.write(source, 'capture')
      cache = ActiveSupport::Cache::MemoryStore.new
      index = Tv::CaptureEpisodeIndex.new(capture_roots: [captures], quarantine_roots: [quarantine], cache: cache)
      detector = Tv::CaptureEpisodeAcquisitions.new(index: index)
      travel_to Time.utc(2026, 10, 29, 12) do
        assert_equal 'capture', detector.call([programme]).fetch(7).kind
        File.rename(source, File.join(quarantine, name))
        travel 61.seconds
        result = detector.call([programme]).fetch(7)
        assert_equal 'quarantine', result.kind
        assert_equal [File.join(quarantine, name)], result.paths
        assert_match 'ne garantit', result.description
      end
    end
  end

  test 'ignores empty sources symlinks another episode and a contradictory title' do
    Dir.mktmpdir do |root|
      prefix = File.join(root, 'Joséphine, ange gardien - ')
      File.write("#{prefix}S12 E11 - Chasse aux fantômes.m2t", '')
      File.write("#{prefix}S12 E10 - Chasse aux fantômes.m2t", 'capture')
      File.write("#{prefix}S12 E11 - Autre épisode.m2t", 'capture')
      File.write("#{prefix}S12 E11 - E12.m2t", 'capture')
      target = File.join(root, 'capture.dat')
      File.write(target, 'capture')
      File.symlink(target, "#{prefix}S12 E11 - Chasse aux fantômes.ts")
      index = Tv::CaptureEpisodeIndex.new(capture_roots: [root], quarantine_roots: [],
                                         cache: ActiveSupport::Cache::MemoryStore.new)
      assert_empty Tv::CaptureEpisodeAcquisitions.new(index: index).call([programme])
    end
  end

  test 'reads natural French numbering and uppercase capture extensions' do
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'Joséphine, ange gardien - Saison 12, épisode 11 - Chasse aux fantômes.M2T'), 'capture')
      index = Tv::CaptureEpisodeIndex.new(capture_roots: [root], quarantine_roots: [],
                                         cache: ActiveSupport::Cache::MemoryStore.new)
      assert_equal 'capture', Tv::CaptureEpisodeAcquisitions.new(index: index).call([programme]).fetch(7).kind
    end
  end
  test 'recognizes a non numbered documentary source regardless of its descriptive subtitle' do
    Dir.mktmpdir do |root|
      name = 'États-Unis - La fuite des cerveaux vers l’Europe'
      File.write(File.join(root, "#{name}.m2t"), 'capture')
      item = Programme.new(9, [{ 'value' => name, 'language' => 'fr' }], [], [{ 'value' => 'Documentaire' }])
      index = Tv::CaptureEpisodeIndex.new(capture_roots: [], quarantine_roots: [root],
                                         cache: ActiveSupport::Cache::MemoryStore.new)
      result = Tv::CaptureEpisodeAcquisitions.new(index: index).call([item]).fetch(9)
      assert_equal 'quarantine', result.kind
      assert_equal [File.join(root, "#{name}.m2t")], result.paths
      item.titles = [{ 'value' => 'Un autre documentaire' }]
      assert_empty Tv::CaptureEpisodeAcquisitions.new(index: index).call([item])
    end
  end

  test 'a project alone is not a completed output or a captured source' do
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'Documentaire.json'), '{}')
      item = Programme.new(9, [{ 'value' => 'Documentaire' }], [], [])
      index = Tv::CaptureEpisodeIndex.new(capture_roots: [root], quarantine_roots: [],
                                         cache: ActiveSupport::Cache::MemoryStore.new)
      assert_empty Tv::CaptureEpisodeAcquisitions.new(index: index).call([item])
    end
  end

end
