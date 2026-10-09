class RecordChildrenCopyUpdate
  def initialize(record:, attributes:)
    @record = record
    @attributes = attributes
  end

  def call
    return if @attributes.empty?

    ids = @record.state_leaves.map(&:id)
    VideoAsset.where(record_id: ids, status: "present").order(:id).each do |asset|
      details = asset.technical_details.deep_dup
      qualify_language(details, asset) if language_changed?(asset)
      asset.update!(@attributes.merge(technical_details: details))
    end
  end

  private

  def language_changed?(asset)
    @attributes.key?(:language_version_id) && asset.language_version_id != @attributes[:language_version_id]
  end

  def qualify_language(details, asset)
    preserve_history(details, asset)
    details["language_qualification"] = {
      "basis" => "manual", "reason" => "Qualification manuelle",
      "language_version" => LanguageVersion.find(@attributes[:language_version_id]).short_name,
      "applied_at" => Time.current.iso8601
    }
  end

  def preserve_history(details, asset)
    details["language_qualification_history"] ||= []
    details["language_qualification_history"] << {
      "language_version_id" => asset.language_version_id,
      "qualification" => details["language_qualification"], "replaced_at" => Time.current.iso8601
    }
  end
end
