# frozen_string_literal: true

require 'tempfile'

module VideoAssets
  # Bounded round-robin: one unresolved or broken copy cannot starve later copies.
  class AutomaticLanguageSweep
    def initialize(directory:, qualifier: AutomaticLanguageQualification.new, limit: 50)
      @directory = Pathname.new(directory)
      @qualifier = qualifier
      @limit = Integer(limit)
      raise ArgumentError, 'Invalid qualification batch size' unless @limit.between?(1, 1000)
    end

    def call
      @directory.mkpath
      scope = VideoAsset.where(status: 'present', language_version_id: nil).order(:id)
      recent, following = selection(scope, cursor)
      results = (recent + following).map { |id| qualify(id) }
      publish('language-qualification.cursor', following.last.to_s) if following.any?
      report = { processed: results.size, copies: results }
      publish('automatic-languages.json', JSON.pretty_generate(report))
      report
    end

    private

    def selection(scope, after)
      recent = scope.where(created_at: 1.day.ago..).reorder(created_at: :desc, id: :desc).limit(@limit / 2).pluck(:id)
      backlog = scope.where.not(id: recent)
      following = backlog.where('id > ?', after).limit(@limit - recent.size).pluck(:id)
      following = backlog.limit(@limit - recent.size).pluck(:id) if following.empty?
      [recent, following]
    end

    def cursor
      file = @directory.join('language-qualification.cursor')
      return 0 unless file.file?

      value = file.read.strip
      raise ArgumentError, 'Invalid language qualification cursor' unless value.match?(/\A\d+\z/)

      value.to_i
    end

    def qualify(id)
      result = @qualifier.call(asset_id: id, apply: true)
      status = result[:status] || (result[:applied] ? 'qualified' : 'unchanged')
      { video_asset_id: id, status: status, proposal: result[:proposal] }
    rescue ArgumentError, KeyError, IOError, SystemCallError, ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("Automatic language qualification #{id}: #{e.class}: #{e.message}")
      { video_asset_id: id, status: 'error', error: "#{e.class}: #{e.message}" }
    end

    def publish(name, contents)
      Tempfile.create(['language-', '.tmp'], @directory.to_s) do |file|
        file.chmod(0o600)
        file.write(contents)
        file.flush
        file.fsync
        File.rename(file.path, @directory.join(name))
      end
    end
  end
end
