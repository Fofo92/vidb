require 'test_helper'

class ReconciliationWorkbenchSeriesEpisodeFileTest < ActiveSupport::TestCase
  def matches?(filename, prefixes: ['Code Quantum', 'Quantum Leap'], path: nil)
    row = { 'path' => path || "/videos/serie/#{filename}", 'local_season' => 3,
      'local_episode' => 4, 'observed_title' => 'La corde raide' }
    ReconciliationWorkbench::SeriesEvidence.file_matches?(row, '/videos/serie', prefixes: prefixes)
  end

  test 'plain series names original names and verified initials are accepted' do
    assert matches?('S03 E04 - La corde raide.avi')
    assert matches?('Code quantum S03 E04 - La corde raide.avi')
    assert matches?('Quantum Leap - S03 E04 - La corde raide.MKV')
    assert matches?('CQ - S03 E04 - La corde raide.m4v')
    assert matches?('MAP - S03 E04 - La corde raide.m4v', prefixes: ['Meurtres au Paradis'])
  end

  test 'unrelated series names and initials remain excluded' do
    assert_not matches?('Autre série S03 E04 - La corde raide.avi')
    assert_not matches?('MAP - S03 E04 - La corde raide.avi')
    assert_not matches?('Code Quantum S03 E04 - La corde raide.avi', prefixes: [])
  end

  test 'ambiguous numbers multi episode names wrong numbers and titles cannot be hidden by prefixes' do
    assert_not matches?('Code quantum S03 E04 S03 E05 - La corde raide.avi')
    assert_not matches?('Code quantum S03 E04 & 05 - La corde raide.avi')
    assert_not matches?('Code quantum S03 E05 - La corde raide.avi')
    assert_not matches?('Code quantum S03 E04 - Un autre titre.avi')
    assert_not matches?('Code quantum E04 - La corde raide.avi')
  end

  test 'extension and directory guards remain enforced' do
    assert_not matches?('Code quantum S03 E04 - La corde raide.txt')
    assert_not matches?('unused', path: '/videos/series/S03 E04 - La corde raide.avi')
    assert_not matches?('unused', path: '/videos/serie/../other/S03 E04 - La corde raide.avi')
  end
end
