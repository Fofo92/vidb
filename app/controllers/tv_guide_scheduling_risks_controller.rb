class TvGuideSchedulingRisksController < ApplicationController
  def create
    source = Tv::GuideSource.where(enabled: true).find(params.require(:guide_source_id))
    date = Date.iso8601(params.require(:date))
    programmes = Tv::DailyGuide.new(guide_source: source, date:).call
                               .where(id: programme_ids)
                               .includes(:recording_intent, guide_channel: :channel)
    render json: Tv::GuideSchedulingRisks.new.call(programmes)
  rescue ArgumentError, ActionController::ParameterMissing
    head :bad_request
  end

  private

  def programme_ids
    Array(params[:programme_ids]).first(2000).map { |value| Integer(value.to_s, 10) }
  end
end
