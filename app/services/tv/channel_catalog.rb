module Tv
  class ChannelCatalog
    Entry = Data.define(
      :external_id,
      :logical_number,
      :display_name
    )

    ENTRIES = [
      Entry.new(external_id: "TF1.fr", logical_number: 1, display_name: "TF1"),
      Entry.new(external_id: "France2.fr", logical_number: 2, display_name: "France 2"),
      Entry.new(external_id: "France3.fr", logical_number: 3, display_name: "France 3"),
      Entry.new(external_id: "France4.fr", logical_number: 4, display_name: "France 4"),
      Entry.new(external_id: "France5.fr", logical_number: 5, display_name: "France 5"),
      Entry.new(external_id: "M6.fr", logical_number: 6, display_name: "M6"),
      Entry.new(external_id: "Arte.fr", logical_number: 7, display_name: "Arte"),
      Entry.new(external_id: "LaChaineParlementaire.fr", logical_number: 8, display_name: "LCP"),
      Entry.new(external_id: "W9.fr", logical_number: 9, display_name: "W9"),
      Entry.new(external_id: "TMC.fr", logical_number: 10, display_name: "TMC"),
      Entry.new(external_id: "NT1.fr", logical_number: 11, display_name: "TFX"),
      Entry.new(external_id: "Gulli.fr", logical_number: 12, display_name: "Gulli"),
      Entry.new(external_id: "CNews.fr", logical_number: 13, display_name: "CNews"),
      Entry.new(external_id: "BFMTV.fr", logical_number: 14, display_name: "BFM TV"),
      Entry.new(external_id: "LCI.fr", logical_number: 15, display_name: "LCI"),
      Entry.new(external_id: "FranceInfo.fr", logical_number: 16, display_name: "France Info"),
      Entry.new(external_id: "CStar.fr", logical_number: 17, display_name: "CStar"),
      Entry.new(external_id: "T18.fr", logical_number: 18, display_name: "T18"),
      Entry.new(external_id: "NOVO19.fr", logical_number: 19, display_name: "NOVO19"),
      Entry.new(external_id: "TF1SeriesFilms.fr", logical_number: 20, display_name: "TF1 Séries Films"),
      Entry.new(external_id: "LEquipe21.fr", logical_number: 21, display_name: "L’Équipe"),
      Entry.new(external_id: "6ter.fr", logical_number: 22, display_name: "6ter"),
      Entry.new(external_id: "Numero23.fr", logical_number: 23, display_name: "RMC Story"),
      Entry.new(external_id: "RMCDecouverte.fr", logical_number: 24, display_name: "RMC Découverte"),
      Entry.new(external_id: "Cherie25.fr", logical_number: 25, display_name: "RMC Life"),
      Entry.new(external_id: "ParisPremiere.fr", logical_number: 31, display_name: "Paris Première")
    ].freeze

    INDEX = ENTRIES.index_by(&:external_id).freeze

    def self.entries
      ENTRIES
    end

    def self.find(external_id)
      INDEX[external_id]
    end
  end
end
