# frozen_string_literal: true

require 'json'

module VideoAssets
  # Dashboard of the last saved scan, never a filesystem scan during a request.
  class ReconciliationOverview
    def initialize(path: nil, cache: Rails.cache)
      @path = Pathname.new(path || ENV.fetch('VIDB_RECONCILIATION_FOLLOWUP_PATH', default_path))
      @cache = cache
    end

    def call
      stat = @path.stat
      key = ['reconciliation-overview-v1', @path.to_s, stat.size, stat.mtime.to_f, stat.ctime.to_f]
      @cache.fetch(key, expires_in: 1.hour) { summarize(JSON.parse(@path.read).deep_symbolize_keys) }
    rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError, KeyError, ArgumentError, TypeError, NoMethodError
      { available: false }
    end

    private

    def default_path
      return '/srv/vidb/shared/reconciliation-followup/current.json' if Rails.env.production?

      Rails.root.join('tmp/reconciliation-followup/current.json').to_s
    end

    def summarize(followup)
      validate!(followup)
      counts = followup.fetch(:entries).group_by { |entry| BlockageCategory.call(entry) }.transform_values(&:count)
      excluded = counts.sum { |category, count| category.start_with?('excluded_') ? count : 0 }
      total = followup[:entries].size - excluded
      confirmed = counts.fetch('confirmed', 0)
      totals(followup, counts, excluded, total, confirmed)
    end

    def validate!(followup)
      return if followup[:format] == ReconciliationFollowup::FORMAT && followup[:version] == 1

      raise ArgumentError, 'Unsupported followup'
    end

    def totals(followup, counts, excluded, total, confirmed)
      { available: true, inventory_at: Time.iso8601(followup.fetch(:inventory_at)),
        total: total, confirmed: confirmed, remaining: total - confirmed, excluded: excluded,
        percent: total.zero? ? 0.0 : (100.0 * confirmed / total).round(1),
        counts: counts.reject { |category, _count| category == 'confirmed' || category.start_with?('excluded_') },
        absent: followup.fetch(:absent_since_previous, []).size }
    end
  end
end
