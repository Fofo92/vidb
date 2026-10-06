module Tv
  class XmltvChannelSelection
    def initialize(guide_source)
      @guide_source = guide_source
    end

    def call
      disabled = Channel.where(enabled: false).pluck(:logical_number)
      catalog = ChannelCatalog.entries.reject { |entry| disabled.include?(entry.logical_number) }
      linked = @guide_source.guide_channels.joins(:channel)
                            .where(tv_channels: { enabled: true }).pluck(:external_id)
      excluded = @guide_source.guide_channels.joins(:channel)
                              .where(tv_channels: { enabled: false }).pluck(:external_id)
      (catalog.map(&:external_id) + linked).uniq - excluded
    end
  end
end
