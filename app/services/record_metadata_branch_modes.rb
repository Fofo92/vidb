# frozen_string_literal: true

module RecordMetadataBranchModes
  private

  def effective_values(record, field, overrides: {})
    root = forcing_root(record)
    imposed = imposed_values(root, field, overrides)
    return imposed if imposed

    baseline = values_for_mode(record, field, configured_mode(root, field, overrides), root)
    season = season_for(record, root)
    season ? season_values(season, field, overrides, baseline) : baseline
  end

  def imposed_values(parent, field, overrides)
    return unless configured_mode(parent, field, overrides) == 'parent'

    common = explicit(parent, field).uniq(&:id)
    common if self.class.forceable?(field, common)
  end

  def configured_mode(parent, field, overrides)
    return 'current' unless parent

    overrides.fetch(parent.id) { parent.public_send(RecordMetadataValues::MODE_ATTRIBUTES.fetch(field)) }
  end

  def season_for(record, root)
    return unless root&.record_kind_series? && record.record_kind_episode?

    parent = @by_id[record.parent_id]
    parent if parent&.record_kind_season?
  end

  def season_values(season, field, overrides, baseline)
    mode = configured_mode(season, field, overrides)
    common = explicit(season, field).uniq(&:id)
    return (baseline + common).uniq(&:id) if mode == 'add'
    return common if mode == 'parent' && self.class.forceable?(field, common)

    baseline
  end

  def additive_values(record, field, common)
    parent = @by_id[record.parent_id]
    seasonal = parent&.record_kind_season? ? explicit(parent, field) : []
    (values(record, field) + seasonal + common).uniq(&:id)
  end

  def forcing_root(record)
    return record if self.class.forcing_root?(record)

    parent = @by_id[record.parent_id]
    case record.record_kind
    when 'standalone_video' then parent if parent&.record_kind_collection? && parent.root?
    when 'season' then parent if parent&.record_kind_series? && parent.root?
    when 'episode' then episode_forcing_root(parent)
    end
  end

  def episode_forcing_root(parent)
    parent = @by_id[parent.parent_id] if parent&.record_kind_season?
    parent if parent&.record_kind_series? && parent.root?
  end
end
