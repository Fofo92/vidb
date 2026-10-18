module ReconciliationWorkbench
  class MetadataAction
    def call(item)
      payload = item.payload
      return SeasonTitleAction.new.call(payload) if item.rule_key == Rules::SEASON_TITLES.key
      return SeriesStructureAction.new.call(payload) if item.rule_key == Rules::SOURCED_STRUCTURE.key
      return structure(payload) if item.rule_key == Rules::STRUCTURE.key

      record = Record.find(payload.fetch('record_id'))
      field = payload.fetch('field')
      before = field == 'genres' ? record.genders.order(:name).pluck(:name) : record.public_send(field)
      raise ArgumentError, 'Valeur actuelle différente de la proposition' unless before == payload.fetch('before')

      apply_field(item, record, field)
      { record_id: record.id, field: field, before: before, after: payload.fetch('value') }
    end

    private

    def apply_field(item, record, field)
      payload = item.payload
      evidence = payload.slice('sources', 'reason', 'identity').merge('case_id' => item.id)
      value = payload.fetch('value')
      case field
      when 'genres' then genres(record, value, evidence, item.id)
      when 'year' then record.update!(year: value, year_basis: payload.fetch('year_basis'), year_evidence: evidence)
      when 'abstract' then abstract(item, record, value, evidence)
      else record.update!(field => value)
      end
    end

    def abstract(item, record, value, evidence)
      return record.save_external_abstract!(value, source: evidence) unless record.abstract_protected?
      raise ArgumentError, 'Résumé protégé : arbitrage explicite requis' unless item.rule_key.end_with?('_replace')

      record.update!(abstract: value)
    end

    def structure(payload)
      records = payload.fetch('roles').keys.map { |id| Record.find(id) }
      records.sort_by { |record| [record.ancestry.to_s.split('/').size, record.id] }.each do |record|
        qualify(record, payload.fetch('roles').fetch(record.id.to_s))
      end
      { qualified_records: records.size }
    end

    def qualify(record, kind)
      raise ArgumentError, 'Nature déjà modifiée' unless ['undetermined', kind].include?(record.record_kind)
      return if record.record_kind == kind

      before = record.attributes
      record.update!(record_kind: kind)
      changed = before.keys.reject { |key| before[key] == record.attributes[key] }
      raise ArgumentError, 'Une autre métadonnée serait modifiée' unless (changed - %w[record_kind updated_at]).empty?
    end

    def genres(record, value, evidence, case_id)
      genders = Gender.where(name: value).order(:name).to_a
      raise ArgumentError, 'Référence de genre manquante' unless genders.map(&:name) == value

      receipt = { 'origin' => 'documented_review', 'protected' => true, 'genres' => value,
                  'operation_id' => "workbench:#{case_id}", 'evidence' => evidence,
                  'history' => [record.genre_provenance], 'recorded_at' => Time.current.iso8601 }
      record.with_reviewed_genre_assignment do
        record.genders = genders
        record.update!(genre_provenance: receipt)
      end
    end
  end
end
