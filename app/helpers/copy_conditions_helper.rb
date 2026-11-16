# frozen_string_literal: true

module CopyConditionsHelper
  INTEGRALITY_LABELS = { 'unknown' => 'Intégralité non vérifiée', 'complete' => 'Intégrale',
                         'incomplete' => 'Incomplète' }.freeze
  DAMAGE_LABELS = { 'unknown' => 'Détérioration non évaluée', 'none' => 'Aucune détérioration signalée',
                    'light' => 'Un peu détériorée (d)', 'severe' => 'Plus sévèrement détériorée (dd)' }.freeze
  PORTION_LABELS = { 'unknown' => 'Non précisée', 'beginning' => 'Début conservé — fin manquante',
                     'end' => 'Fin conservée — début manquant' }.freeze

  def copy_condition_lines(asset)
    details = asset.effective_condition
    lines = [copy_integrality_label(details),
             DAMAGE_LABELS.fetch(details.fetch('damage', 'unknown'))]
    part = details.fetch('retained_portion', 'unknown')
    lines << PORTION_LABELS.fetch(part) unless part == 'unknown'
    seconds = details['retained_duration_seconds']
    lines << "Durée conservée : #{retained_duration_label(seconds)}" if seconds
    lines << 'Marqueurs à qualifier' if details['needs_review']
    lines
  end

  def retained_duration_label(seconds)
    minutes, remainder = seconds.divmod(60)
    remainder.zero? ? "#{minutes} min" : "#{minutes} min #{remainder} s"
  end

  def copy_condition_summary(asset)
    details = asset.effective_condition
    damage = { 'light' => 'd', 'severe' => 'dd' }[details['damage']]
    duration = retained_duration_label(details['retained_duration_seconds']) if details['retained_duration_seconds']
    [copy_integrality_label(details, compact: true), damage, duration].compact.join(' · ')
  end

  def copy_integrality_label(details, compact: false)
    return 'Présumée complète' if details['integrality'] == 'complete' &&
                                  Array(details['presumed_fields']).include?('integrality')
    return 'À vérifier' if compact && details.fetch('integrality', 'unknown') == 'unknown'

    INTEGRALITY_LABELS.fetch(details.fetch('integrality', 'unknown'))
  end
end
