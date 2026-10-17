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

  def workbench_value(field, value)
    return 'Non renseigné' if value.blank?
    return value.join(', ') if value.is_a?(Array)

    reference = { 'country_id' => Country, 'language_version_id' => LanguageVersion }[field]
    return reference.find_by(id: value)&.long_name || value if reference

    value
  end
end
