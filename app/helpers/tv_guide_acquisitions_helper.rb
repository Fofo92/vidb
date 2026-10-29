module TvGuideAcquisitionsHelper
  ACQUISITION_ADVICE = {
    'recommended' => 'Nouvelle capture utile',
    'unnecessary' => 'Nouvelle capture non nécessaire',
    'review' => 'Acquisition à vérifier'
  }.freeze

  def tv_guide_acquisition_tone(acquired:, previous:, scheduled:, selected:)
    return 'unnecessary' if selected || scheduled
    return previous ? 'unnecessary' : 'recommended' unless acquired
    return 'unnecessary' if %w[available capture quarantine].include?(acquired.kind)
    return 'recommended' if %w[reencode history recorded].include?(acquired.kind)

    'review'
  end

  def tv_guide_acquisition_advice(tone)
    ACQUISITION_ADVICE.fetch(tone)
  end
end
