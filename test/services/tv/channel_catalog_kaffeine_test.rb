require "test_helper"

module Tv
  class ChannelCatalogKaffeineTest < ActiveSupport::TestCase
    EXPECTED_NAMES = {
      "TF1.fr" => "TF1",
      "France2.fr" => "France 2",
      "France3.fr" => "F3 Paris Ile-de-France",
      "France4.fr" => "France 4",
      "France5.fr" => "France 5",
      "M6.fr" => "M6",
      "Arte.fr" => "Arte",
      "LaChaineParlementaire.fr" => "LCP",
      "W9.fr" => "W9",
      "TMC.fr" => "TMC",
      "NT1.fr" => "TFX",
      "Gulli.fr" => "Gulli",
      "CNews.fr" => "CNEWS",
      "BFMTV.fr" => "BFM TV",
      "LCI.fr" => "LCI",
      "FranceInfo.fr" => "franceinfo:",
      "CStar.fr" => "CSTAR",
      "T18.fr" => "T18",
      "NOVO19.fr" => "NOVO19",
      "TF1SeriesFilms.fr" => "TF1 Séries Films",
      "LEquipe21.fr" => "L'Equipe",
      "6ter.fr" => "6Ter",
      "Numero23.fr" => "RMC STORY",
      "RMCDecouverte.fr" => "RMC Découverte",
      "Cherie25.fr" => "RMC Life",
      "ParisPremiere.fr" => "PARIS PREMIERE"
    }.freeze

    test "maps confirmed XMLTV channels to Kaffeine names" do
      EXPECTED_NAMES.each do |external_id, kaffeine_name|
        assert_equal(
          kaffeine_name,
          ChannelCatalog.find(external_id).kaffeine_name
        )
      end
    end
  end
end
