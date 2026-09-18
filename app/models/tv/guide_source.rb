module Tv
  class GuideSource < ApplicationRecord
    has_many :guide_channels, dependent: :restrict_with_error
    has_many :guide_imports, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
    validates :display_name, :time_zone, presence: true

    def latest_successful_import
      guide_imports.status_succeeded
                   .order(started_at: :desc, id: :desc)
                   .first
    end
  end
end
