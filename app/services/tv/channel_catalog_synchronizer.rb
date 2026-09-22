module Tv
  class ChannelCatalogSynchronizer
    def initialize(guide_source)
      @guide_source = guide_source
    end

    def call
      Channel.transaction do
        @guide_source.guide_channels.find_each do |guide_channel|
          synchronize(guide_channel)
        end
      end
    end

    private

    def synchronize(guide_channel)
      entry = ChannelCatalog.find(guide_channel.external_id)
      return unless entry

      channel = Channel.find_or_initialize_by(
        logical_number: entry.logical_number
      )
      channel.display_name = entry.display_name
      channel.save!

      guide_channel.update!(channel: channel)
    end
  end
end
