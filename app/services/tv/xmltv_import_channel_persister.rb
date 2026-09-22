module Tv
  class XmltvImportChannelPersister
    def initialize(guide_source:, channels:)
      @guide_source = guide_source
      @channels = channels
    end

    def call
      guide_channels = @channels.transform_values do |channel|
        persist(channel)
      end

      ChannelCatalogSynchronizer.new(@guide_source).call
      guide_channels
    end

    private

    def persist(channel)
      guide_channel = @guide_source.guide_channels
                                   .find_or_initialize_by(
                                     external_id: channel.external_id
                                   )
      display_names = channel.display_names.map(&:stringify_keys)

      guide_channel.display_names =
        (guide_channel.display_names + display_names).uniq
      guide_channel.save!
      guide_channel
    end
  end
end
