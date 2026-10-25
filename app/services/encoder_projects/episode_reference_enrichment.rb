module EncoderProjects
  class EpisodeReferenceEnrichment
    def initialize(candidate, parameters)
      @candidate = candidate
      @parameters = parameters
    end

    def selected_ids(name)
      posted = Array(@parameters[name]).reject(&:blank?)
      return posted.map { |value| Integer(value.to_s, 10) }.uniq if posted.any?

      @candidate.fetch(name, [])
    end

    def call(record)
      genders = selected_ids('gender_ids')
      countries = selected_ids('country_ids')
      raise ArgumentError, 'Choisis au maximum deux genres' if genders.size > 2
      raise ArgumentError, 'Trop de pays sélectionnés' if countries.size > 10

      assign_references(record, genders, countries)
    end

    def assign_references(record, genders, countries)
      series = record.parent.parent
      series.lock!
      assign_genders(record, series, genders)
      assign_countries(record, series, countries)
    end

    def assign_genders(record, series, genders)
      assign_reference(record, series, :genders, 'gender_ids', genders)
    end

    def assign_countries(record, series, countries)
      assign_reference(record, series, :countries, 'country_ids', countries)
    end

    def assign_reference(record, series, association, parameter, ids)
      current = record.public_send("effective_#{association}").map(&:id).sort
      explicit = explicit_ids?(parameter, ids)
      return if retain_reference?(current, ids, explicit)

      check_unchanged!(current, @candidate.fetch(parameter, []).sort) if explicit && current.any?
      target = series.public_send(association).empty? ? series : record
      persist_reference(target, association, ids)
    end

    def explicit_ids?(parameter, ids)
      @parameters[parameter].present? && @candidate.key?(parameter) && ids.sort != @candidate[parameter].sort
    end

    def persist_reference(target, association, ids)
      if association == :genders
        target.with_reviewed_genre_assignment { target.genders = Gender.find(ids) }
      else
        target.countries = Country.find(ids)
      end
    end

    def retain_reference?(current, ids, explicit)
      ids.empty? || current == ids.sort || (current.any? && !explicit)
    end

    def check_unchanged!(current, previous)
      raise ArgumentError, 'Fiche modifiée depuis la proposition : recharge le formulaire.' unless current == previous
    end
  end
end
