require 'test_helper'

class Tv::AcquiredEpisodesTest < ActiveSupport::TestCase
  Programme = Struct.new(:id, :titles, :episode_numbers, :subtitles)

  def programmes
    [7, 8].map do |id|
      Programme.new(id, [{ 'value' => 'NCIS' }], [{ 'system' => 'xmltv_ns', 'value' => '12.18.' }],
                    [{ 'value' => 'Un doute raisonnable' }])
    end
  end

  def acquisition(kind, record_id: nil)
    Tv::EpisodeAcquisition.new(kind: kind, label: kind, description: "Détail #{kind}",
                               record_id: record_id, paths: ["/sources/#{kind}.m2t"])
  end

  def detect(copies, sources)
    library = Object.new
    library.define_singleton_method(:call) { |_| copies }
    captures = Object.new
    observed = nil
    captures.define_singleton_method(:call) do |items|
      observed = items.map(&:id)
      sources.slice(*observed)
    end
    result = Tv::AcquiredEpisodes.new(library: library, captures: captures).call(programmes)
    [result, observed]
  end

  test 'a complete video_encoder copy stays first and does not require a source lookup' do
    encoded = acquisition('available')
    source = acquisition('quarantine')
    result, observed = detect({ 7 => encoded }, { 8 => source })
    assert_equal({ 7 => encoded, 8 => source }, result)
    assert_equal [8], observed
  end

  test 'an existing NCIS source takes priority over an old copy awaiting replacement' do
    old_copy = acquisition('reencode', record_id: 42)
    source = acquisition('capture')
    result, observed = detect({ 7 => old_copy }, { 7 => source })
    assert_includes observed, 7
    assert_equal 'capture', result.fetch(7).kind
    assert_equal source.paths, result.fetch(7).paths
    assert_equal 42, result.fetch(7).record_id
    assert_includes result.fetch(7).description, 'Détail reencode'
    assert_equal 'Détail capture', source.description
    assert_equal 'Détail reencode', old_copy.description
  end

  test 'quarantine also takes priority over historical or uncertain library evidence' do
    %w[history recorded project_review].each do |kind|
      result, = detect({ 7 => acquisition(kind) }, { 7 => acquisition('quarantine') })
      assert_equal 'quarantine', result.fetch(7).kind
    end
  end

  test 'an old copy keeps its replacement indication when no source exists' do
    old_copy = acquisition('reencode')
    result, = detect({ 7 => old_copy }, {})
    assert_equal old_copy, result.fetch(7)
  end
end
