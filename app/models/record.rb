class Record < ApplicationRecord
  paginates_per 26
  belongs_to :language_version
  has_and_belongs_to_many :media
  has_and_belongs_to_many :genders
  has_and_belongs_to_many :countries
  has_ancestry
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

  def self.ransackable_attributes(auth_object = nil)
    ["french_title", "original_title"]
  end

  def formatted_length(length_in_mn)
    seconds = length_in_mn.to_i * 60
    Time.at(seconds.to_i).utc.strftime("%Hh%M")
  end

  def display_range_of_years
    years = []
    descendants.each do |child|
      years.push(child.year)
    end
    years.compact!

    return "n/a" if years.empty?

    return years.compact.min.eql?(years.max) ? years.min.to_s : "#{years.min}-#{years.max}"

  end

  def complete_title
    if original_title.blank?
      french_title.to_s
    else
      french_title ? "#{french_title} (#{original_title})" : original_title.to_s
    end
  end

  def complete_title_with_parents
    return complete_title unless ancestors?

    complete_title_with_parents = ""
    ancestors.each do |ancestor|
      complete_title_with_parents += "#{ancestor.complete_title} / "
    end
    return complete_title_with_parents << complete_title
  end

  def child_length_in_mn
    return unless has_children? && length_in_mn.zero?

    child_length_in_mn = 0
    children.each do |child|
      child_length_in_mn += child.length_in_mn.to_i unless child.length_in_mn.zero?
    end
    child_length_in_mn.to_i unless length_in_mn.zero?
  end

  def formatted_total_length
    if has_children?
      formatted_total_length_in_mn = 0
      descendants.each do |child|
        formatted_total_length_in_mn += child.length_in_mn.to_i
      end
      formatted_length(formatted_total_length_in_mn)
    else
      formatted_length(length_in_mn)
    end
  end

  def self.number_of_checked_records
    return Record.count(&:is_checked)
  end

  def self.number_of_seen_records
    return Record.count(&:is_seen)
  end

  def self.number_of_unseen_records
    return Record.count { |record| !record.is_seen }
  end

  def self.number_of_seen_and_removed_records
    return Record.count { |record| record.is_seen && record.is_available }
  end

  def self.number_of_seen_and_available_records
    return Record.count { |record| record.is_seen && !record.is_available }
  end

  def self.number_of_unseen_and_available_records
    return Record.count { |record| !record.is_seen && record.is_available }
  end

  def self.number_of_unseen_and_removed_records
    return Record.count { |record| !record.is_seen && !record.is_available }
  end

  def number_of_recorded_children
    return descendants.count(&:is_recorded)
  end

  def number_of_seen_children
    return descendants.count(&:is_seen)
  end

  def number_of_available_children
    return descendants.count(&:is_available)
  end

  private

  def validate_year_range
    return unless year.present? && (year < 1900 || year > Date.today.year)

    errors.add(:year, "doit être compris entre 1900 et #{Date.today.year}")
  end
end
