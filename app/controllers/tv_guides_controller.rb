class TvGuidesController < ApplicationController
  def show
    @guide_source = selected_guide_source
    @date = selected_date
    @programmes_by_channel = programmes_by_channel
  end

  private

  def selected_guide_source
    enabled_sources = Tv::GuideSource.where(enabled: true).order(:id)

    return enabled_sources.find(params[:guide_source_id]) \
      if params[:guide_source_id].present?

    enabled_sources.first
  end

  def programmes_by_channel
    return {} unless @guide_source

    Tv::DailyGuide.new(
      guide_source: @guide_source,
      date: @date
    ).call.includes(:guide_channel).group_by(&:guide_channel)
  end

  def selected_date
    return Date.iso8601(params[:date]) if params[:date].present?

    Time.find_zone!("Europe/Paris").today
  end
end
