module TvGuideAcquisitionsHelper
  ACQUISITION_ADVICE = {
    'recommended' => 'Nouvelle capture utile',
    'unnecessary' => 'Nouvelle capture non nécessaire',
    'review' => 'Acquisition à vérifier'
  }.freeze

  def tv_guide_acquisition_tone(acquired:, previous:)
    return previous ? 'review' : nil unless acquired
    return 'unnecessary' if %w[available capture quarantine].include?(acquired.kind)
    return 'recommended' if %w[reencode replace_copy].include?(acquired.kind)

    'review'
  end

  def tv_guide_acquisition_advice(tone)
    ACQUISITION_ADVICE.fetch(tone)
  end
end
