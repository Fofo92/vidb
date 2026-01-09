class Record < ApplicationRecord
  validates :original_title, presence: { if: -> { french_title.blank? } }
  validates :french_title, presence: { if: -> { original_title.blank? } }
  validate :validate_year_range
  validates :length_in_mn,
            allow_nil: true,
            numericality: {
              greater_than_or_equal_to: 10,
              less_than_or_equal_to: 240,
              only_integer: true
            }
  def formatted_length(length_in_mn)
    seconds = length_in_mn.to_i * 60
    Time.at(seconds.to_i).utc.strftime("%Hh%M")
  end

  def formatted_total_length # sera modifié par la suite
    formatted_length(length_in_mn)
  end

  def complete_title
    if original_title.blank?
      french_title.to_s
    else
      french_title ? "#{french_title} (#{original_title})" : original_title.to_s
    end
  end

  private

  def validate_year_range
    return unless year.present? && (year < 1900 || year > Date.today.year)

    errors.add(:year, "doit être compris entre 1900 et #{Date.today.year}")
  end
end
