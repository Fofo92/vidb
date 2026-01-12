class Record < ApplicationRecord
  paginates_per 26
  belongs_to :language_version, optional: true, default: -> { LanguageVersion.find_by(short_name: 'FR') }
  has_and_belongs_to_many :media
  has_and_belongs_to_many :genders
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

  def self.number_of_checked_records
    return Record.where(is_checked: true).count
  end

  def self.number_of_seen_records
    return Record.where(is_seen: true).count
  end

  def self.number_of_unseen_records
    return Record.where(is_seen: false).count
  end

  def self.number_of_seen_and_removed_records
    return Record.where(is_seen: true, is_available: true).count
  end

  def self.number_of_seen_and_available_records
    return Record.where(is_seen: true, is_available: false).count
  end

  def self.number_of_unseen_and_available_records
    return Record.where(is_seen: false, is_available: true).count
  end

  def self.number_of_unseen_and_removed_records
    return Record.where(is_seen: false, is_available: false).count
  end

  private

  def validate_year_range
    return unless year.present? && (year < 1900 || year > Date.today.year)

    errors.add(:year, "doit être compris entre 1900 et #{Date.today.year}")
  end
end
