require 'test_helper'

class EncoderProjects::CatalogueReferencesTest < ActiveSupport::TestCase
  test 'crime and mystery resolve to policier once before drama' do
    police = Gender.find_or_create_by!(name: 'Policier')
    drama = Gender.find_or_create_by!(name: 'Drame')
    Gender.find_or_create_by!(name: 'Crime')
    Gender.find_or_create_by!(name: 'Mystère')
    ['Crime, Drame, Mystère', 'Crime, Drame, Mystery'].each do |text|
      assert_equal [police.id, drama.id], EncoderProjects::CatalogueReferences.genres('genres_text' => text)
    end
  end

  test 'mystere alone proposes policier without inventing drama' do
    police = Gender.find_or_create_by!(name: 'Policier')
    assert_equal [police.id], EncoderProjects::CatalogueReferences.genres('genres_text' => 'Mystère')
  end

  test 'comedie dramatique still proposes its two local genres' do
    drama = Gender.find_or_create_by!(name: 'Drame')
    comedy = Gender.find_or_create_by!(name: 'Comédie')
    assert_equal [drama.id, comedy.id].sort,
                 EncoderProjects::CatalogueReferences.genres('genres_text' => 'Comédie dramatique').sort
  end
end
