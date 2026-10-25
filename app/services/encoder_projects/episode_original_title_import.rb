module EncoderProjects
  class EpisodeOriginalTitleImport
    def initialize(candidate, parameters)
      @candidate = candidate
      @parameters = parameters
    end

    def call(record, created: false)
      selected = (@parameters['original_title'].presence || @candidate['original_title']).to_s.strip
      return if selected.blank? || selected == record.original_title.to_s
      raise ArgumentError, 'Titre original trop long (300 caractères maximum)' if selected.length > 300
      return unless editable?(record, selected, created)

      check_current!(record) unless created
      record.update!(original_title: selected)
    end

    private

    def editable?(record, selected, created)
      created || record.original_title.blank? || explicit_change?(selected)
    end

    def explicit_change?(selected)
      @parameters['original_title'].present? && @candidate.key?('original_title') &&
        selected != @candidate['original_title']
    end

    def check_current!(record)
      return if record.original_title.blank? && !@candidate.key?('previous_original_title')

      previous = @candidate.fetch('previous_original_title', @candidate['original_title']).to_s
      return if record.original_title.to_s == previous

      raise ArgumentError, 'Titre original modifié depuis la proposition : recharge le formulaire.'
    end
  end
end
