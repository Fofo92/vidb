class TvChannelPreferencesController < ApplicationController
  def edit
    @channels = enabled_channels
  end

  def update
    Tv::Channel.transaction do
      enabled_channels.find_each do |channel|
        channel.update!(
          favorite: selected_channel_ids.include?(channel.id)
        )
      end
    end

    redirect_to(tv_guide_path,
                notice: "Les chaînes favorites ont été mises à jour.")
  end

  private

  def enabled_channels
    Tv::Channel.where(enabled: true)
               .order(:logical_number, :id)
  end

  def selected_channel_ids
    preferences_params.fetch(:channel_ids, [])
                      .compact_blank
                      .map(&:to_i)
  end

  def preferences_params
    params.require(:tv_channel_preferences)
          .permit(channel_ids: [])
  end
end
