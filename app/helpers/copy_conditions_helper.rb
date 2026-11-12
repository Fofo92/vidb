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
    lines = [INTEGRALITY_LABELS.fetch(details.fetch('integrality', 'unknown')),
             DAMAGE_LABELS.fetch(details.fetch('damage', 'unknown'))]
    part = details.fetch('retained_portion', 'unknown')
    lines << PORTION_LABELS.fetch(part) unless part == 'unknown'
    seconds = details['retained_duration_seconds']
    lines << "Durée conservée : #{seconds / 60} min" if seconds
    lines << 'Marqueurs à qualifier' if details['needs_review']
    lines
  end
end
