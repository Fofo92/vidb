class Country < ApplicationRecord
  validates :short_name, presence: true, uniqueness: true
  validates :long_name, presence: true, uniqueness: true
  has_and_belongs_to_many :records

  def country_flag(alpha2)
    return '' unless alpha2 =~ /\A[a-zA-Z]{2}\z/

    to_regional_indicator(alpha2[0, 2])
  end

  def to_regional_indicator(str)
    # Base du point de code pour « A »
    base = 0x1F1E6

    # Sélectionner uniquement les lettres A‑Z, les mettre en majuscules
    letters = str.upcase.scan(/[A-Z]/)

    # Convertir chaque lettre en son emoji indicateur
    emojis = letters.map do |ch|
      codepoint = base + (ch.ord - 'A'.ord)
      codepoint.chr(Encoding::UTF_8)
    end

    emojis.join
  end
end
