module ReconciliationWorkbenchHelper
  def workbench_decision_label(value)
    { 'approved' => 'Règle validée', 'deferred' => 'À préciser', 'rejected' => 'Écartée' }.fetch(value, 'À examiner')
  end

  def workbench_file_count(scope)
    unless ReconciliationCase.connection.adapter_name == 'PostgreSQL'
      return scope.sum do |item|
        item.payload.fetch('file_count', 0)
      end
    end

    scope.sum(Arel.sql("COALESCE((payload->>'file_count')::bigint, 0)"))
  end

  def workbench_applied_structure_exclusions(key = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE.key)
    @workbench_applied_structure_exclusions ||= {}
    @workbench_applied_structure_exclusions[key] ||= ReconciliationCase.current.where(
      rule_key: key, status: 'applied'
    ).order(:id).select { |item| item.payload.fetch('held', []).any? }
  end

  def workbench_legacy_structures(key = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE.key)
    rule = ReconciliationWorkbench::Rules.fetch(key)
    @workbench_legacy_structures ||= {}
    @workbench_legacy_structures[key] ||= ReconciliationCase.current.where(
      rule_key: rule.key, status: %w[pending blocked]
    ).where.not(rule_version: rule.version).order(:id).to_a
  end

  def workbench_track_languages(sample, type)
    streams = sample.dig('measurement', 'technical_details', 'streams')
    return 'À mesurer' unless streams.is_a?(Array)

    tracks = streams.select { |stream| stream['codec_type'] == type }
    return 'Aucun' if tracks.empty?

    tracks.map do |stream|
      language = stream.dig('tags', 'language').presence || 'langue non renseignée'
      "#{language} (piste #{stream['index'] || '?'})"
    end.join(', ')
  end

  def workbench_stream_description(stream)
    types = { 'audio' => 'Audio', 'subtitle' => 'Sous-titres', 'video' => 'Vidéo' }
    parts = [types.fetch(stream['codec_type'], stream['codec_type']), "piste #{stream['index'] || '?'}",
             stream['codec_name'], stream.dig('tags', 'language')]
    parts << "#{stream['channels']} canaux" if stream['channels']
    roles = stream.fetch('disposition', {}).select { |_key, value| value.to_i == 1 }.keys
    parts.concat(roles)
    parts.compact.join(' · ')
  end

  def workbench_value(field, value)
    return 'Non renseigné' if value.blank?
    return value.join(', ') if value.is_a?(Array)

    reference = { 'country_id' => Country, 'language_version_id' => LanguageVersion }[field]
    return reference.find_by(id: value)&.long_name || value if reference

    value
  end
end
