module EncoderProjects
  class EpisodeEnrichment
    def initialize(candidate:, parameters:, project:)
      @candidate = candidate || {}
      @parameters = parameters
      @project = project
    end

    def creation_values
      { title: value('title'), year: parsed_year, source: value('source') }
    end

    def call(record)
      @created = record.previous_changes.key?('id')
      Record.transaction do
        lock_records(record)
        verify!(record)
        fill_editorial(record)
        EpisodeReferenceEnrichment.new(@candidate, @parameters).call(record)
        fill_language(record)
        record
      end
    end

    private

    def lock_records(record)
      record.parent.parent.lock!
      record.lock!
    end

    def value(name)
      fallback = name == 'source' ? @candidate.dig('source', 'url') : @candidate[name]
      fallback ||= EpisodeRequest.new(@project).title if name == 'title'
      @parameters[name].presence || fallback
    end

    def parsed_year
      Integer(value('year').to_s, 10) if value('year').present?
    end

    def verify!(record)
      return if @candidate.empty?
      return if @candidate['series_id'] == record.parent.parent.id && @candidate['season'] == record.parent.rank &&
                @candidate['episode'] == record.rank

      raise ArgumentError, 'La proposition concerne une autre série ou un autre épisode'
    end

    def fill_editorial(record)
      EpisodeOriginalTitleImport.new(@candidate, @parameters).call(record, created: @created)
      fill_year(record)
      fill_abstract(record)
    end

    def fill_year(record)
      return if parsed_year.nil? || (record.year == parsed_year && !@created)

      if record.year.present? && !@created
        return unless explicit_change?('year', parsed_year)

        check_unchanged!(record.year, @candidate['year'])
      end
      record.update!(year: parsed_year, year_basis: 'first_release', year_evidence: year_evidence)
    end

    def explicit_change?(name, selected)
      @parameters[name].present? && @candidate.key?(name) && selected != @candidate[name]
    end

    def check_unchanged!(current, previous)
      raise ArgumentError, 'Fiche modifiée depuis la proposition : recharge le formulaire.' unless current == previous
    end

    def year_evidence
      evidence = @candidate.fetch('source', {}).merge('url' => value('source'))
      evidence['manual_year'] = parsed_year if @candidate['year'] && parsed_year != @candidate['year']
      evidence
    end

    def fill_abstract(record)
      return if value('abstract').blank? || record.abstract == value('abstract')
      return if record.abstract.present? && !summary_change_requested?

      SummaryImport.new(candidate: @candidate, parameters: @parameters).call(record, value('abstract'))
    end

    def summary_change_requested?
      explicit_change?('abstract', value('abstract')) || @candidate['replace_external_abstract']
    end

    def fill_language(record)
      name = @parameters['language_version'].presence || @project['language_hint']
      return if name.blank? || name == record.language_version.short_name

      unless record.language_version.short_name == 'IND'
        return unless explicit_change?('language_version', name)

        check_unchanged!(record.language_version.short_name, @candidate['language_version'])
      end
      record.update!(language_version: LanguageVersion.where(short_name: name).sole)
    end
  end
end
