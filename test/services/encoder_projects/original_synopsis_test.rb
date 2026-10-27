require 'test_helper'

module EncoderProjects
  class OriginalSynopsisTest < ActiveSupport::TestCase
    test 'an original synopsis is shown separately without filling the French synopsis' do
      client = Object.new
      client.define_singleton_method(:get) do |_path, language:|
        raise 'unexpected language' unless language == 'en'

        { 'episodes' => [{ 'id' => 10, 'episode_number' => 3, 'overview' => 'An English synopsis.' }] }
      end
      builder = TmdbEpisodeProposal.new(client: client, wikipedia_page: nil, links: nil, warnings: [])
      builder.instance_variable_set(:@series_data, { 'original_language' => 'en' })
      proposal = { 'abstract' => '', 'source' => { 'episode_id' => 10 } }
      numbers = Struct.new(:season, :episode).new(1, 3)
      result = builder.send(:original_synopsis, proposal, 12, numbers)
      assert_equal '', result['abstract']
      assert_equal 'An English synopsis.', result['abstract_original']
      assert_equal 'en', result['abstract_original_language']
    end

    test 'a French synopsis needs no original language request' do
      builder = TmdbEpisodeProposal.new(client: nil, wikipedia_page: nil, links: nil, warnings: [])
      proposal = { 'abstract' => 'Résumé français.' }
      assert_same proposal, builder.send(:original_synopsis, proposal, 12, nil)
    end
  end
end
