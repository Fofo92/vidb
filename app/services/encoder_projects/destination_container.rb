module EncoderProjects
  class DestinationContainer
    def self.call(record)
      return {} unless record.record_kind_standalone_video?

      parent = record.parent
      return {} unless parent && %w[collection series].include?(parent.record_kind)

      { 'destination_container' => parent.attributes.slice('french_title', 'original_title', 'record_kind').merge(
        'countries' => parent.effective_countries.map(&:long_name)
      ) }
    end
  end
end
