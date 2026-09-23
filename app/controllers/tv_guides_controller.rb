class TvGuidesController < ApplicationController
  MINUTE_HEIGHTS = [1, 2, 4].freeze
  DEFAULT_MINUTE_HEIGHT = 2
  MINIMUM_PROGRAMME_HEIGHT = 24

  def show
    @guide_source = selected_guide_source
    @date = selected_date
    @minute_height = selected_minute_height
    @programmes_by_channel = programmes_by_channel
    @timelines_by_channel = timelines_by_channel
    @minimum_programme_height = MINIMUM_PROGRAMME_HEIGHT
    @timeline_projection = timeline_projection
  end

  private

  def timeline_projection
    timeline = @timelines_by_channel.values.first
    return unless timeline

    Tv::DailyGuideProjection.new(
      duration_minutes: timeline.duration_minutes,
      programme_ranges: programme_ranges,
      pixels_per_minute: @minute_height,
      minimum_programme_height: MINIMUM_PROGRAMME_HEIGHT
    )
  end

  def programme_ranges
    @timelines_by_channel.values.flat_map do |timeline|
      timeline.items.map do |item|
        [
          item.start_minute,
          item.start_minute + item.duration_minutes
        ]
      end
    end
  end

  def selected_minute_height
    requested_height = params[:zoom].to_i

    return requested_height if MINUTE_HEIGHTS.include?(requested_height)

    DEFAULT_MINUTE_HEIGHT
  end

  def selected_guide_source
    enabled_sources = Tv::GuideSource.where(enabled: true).order(:id)

    return enabled_sources.find(params[:guide_source_id]) \
      if params[:guide_source_id].present?

    enabled_sources.first
  end

  def programmes_by_channel
    return {} unless @guide_source

    grouped_programmes
      .select { |channel, _| channel.channel&.enabled? }
      .sort_by { |channel, _| channel.channel.logical_number }
      .to_h
  end

  def timelines_by_channel
    @programmes_by_channel.transform_values do |programmes|
      Tv::DailyGuideTimeline.new(
        date: @date,
        programmes: programmes
      ).call
    end
  end

  def grouped_programmes
    Tv::DailyGuide.new(
      guide_source: @guide_source,
      date: @date
    ).call.includes(guide_channel: :channel)
                  .group_by(&:guide_channel)
  end

  def selected_date
    return Date.iso8601(params[:date]) if params[:date].present?

    Time.find_zone!("Europe/Paris").today
  end
end
