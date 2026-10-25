require 'test_helper'

class EncoderProjects::SynopsisDefaultsTest < ActiveSupport::TestCase
  RecordDouble = Struct.new(:abstract, :manual) do
    def abstract_protected?
      manual
    end

    def abstract_provenance
      { 'source' => { 'provider' => manual ? 'manual' : 'wikipedia' } }
    end
  end

  test 'manual text remains selected while an external replacement carries a baseline' do
    candidate = { 'abstract' => 'Synopsis court.', 'abstract_source' => { 'provider' => 'tmdb' } }
    manual = EncoderProjects::EpisodeDefaults.summary(RecordDouble.new('Mon résumé.', true), candidate)
    assert_equal 'Mon résumé.', manual['abstract']
    refute manual['replace_external_abstract']
    external = EncoderProjects::EpisodeDefaults.summary(RecordDouble.new('Ancien récit.', false), candidate)
    assert_equal 'Synopsis court.', external['abstract']
    assert_equal 'Ancien récit.', external['previous_abstract']
    assert external['replace_external_abstract']
  end
end
