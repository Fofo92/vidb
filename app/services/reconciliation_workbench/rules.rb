module ReconciliationWorkbench
  module Rules
    Rule = Data.define(:key, :version, :axis, :title, :proposal, :limits, :recurring)
    STRUCTURE = Rule.new(
      key: 'existing_episode_structure', version: 1, axis: 'metadata',
      title: 'Préciser les rôles dans une hiérarchie existante',
      proposal: 'Qualifier série, saison et épisodes lorsque les liens, les numéros et les titres concordent déjà.',
      limits: 'Aucun parent créé, aucun déplacement de fiche, aucun titre, genre, année ou langue remplacé.',
      recurring: true
    )
    DISK = Rule.new(
      key: 'unique_stable_copy', version: 1, axis: 'disk',
      title: 'Rattacher une copie stable à une œuvre identifiée',
      proposal: 'Importer la copie si son titre est exact, ou si numéro et titre d’épisode concordent ' \
                'dans une hiérarchie cohérente.',
      limits: 'Œuvre qualifiée, fichier stable 24 h, montage vérifié, aucune copie concurrente. Aucun renommage.',
      recurring: true
    )
    PREFERENCE = Rule.new(
      key: 'richer_encoder_copy', version: 2, axis: 'disk',
      title: 'Privilégier une copie video_encoder plus complète',
      proposal: 'Choisir l’export plus récent, plus riche en pistes et plus petit, sans perdre de piste utile.',
      limits: 'Rattachement du candidat après comparaison validée. Durées à 2 secondes près, définition conservée. ' \
              'Qualité visuelle non évaluée ; tous les fichiers sont conservés.', recurring: true
    )
    MANUAL_COPY = Rule.new(
      key: 'reviewed_copy_preference', version: 1, axis: 'disk', title: 'Choix de copies confirmés',
      proposal: 'Appliquer les choix explicites confirmés pour les copies examinées.',
      limits: 'Décision limitée aux preuves et fichiers examinés. Aucune langue réécrite, aucun fichier supprimé.',
      recurring: false
    )
    FIELDS = %w[year abstract country_id language_version_id genres].freeze
    SEASON_TITLES = Rule.new(
      key: 'generated_season_titles', version: 1, axis: 'metadata',
      title: 'Harmoniser les titres des saisons créées par l’atelier',
      proposal: 'Remplacer Saison 03 par Saison 3 dans le catalogue, pour toutes les séries concernées.',
      limits: 'Création attestée par un reçu de l’atelier et titre généré exact uniquement. ' \
              'Aucun répertoire renommé. Validation limitée aux propositions affichées.', recurring: false
    )
    SOURCED_STRUCTURE = Rule.new(
      key: 'reviewed_series_structure', version: 2, axis: 'metadata',
      title: 'Compléter les structures de séries documentées',
      proposal: 'Créer les saisons et épisodes manquants, qualifier les fiches concordantes ' \
                'ou corriger un rang de saison explicite. Références Wikipédia en français prioritaires.',
      limits: 'Seulement les opérations affichées. Aucun parent changé, aucun titre existant remplacé. ' \
              'Les cas à arbitrer restent de côté. Le rapprochement disque conserve sa validation séparée.',
      recurring: false
    )

    def self.all
      [STRUCTURE, SOURCED_STRUCTURE, SEASON_TITLES, DISK, PREFERENCE, MANUAL_COPY] + FIELDS.flat_map do |field|
        %w[fill replace].map do |mode|
          sourced_rule(field, mode)
        end
      end
    end

    def self.sourced_rule(field, mode)
      limits = if mode == 'fill'
                 'Valeur absente et non protégée uniquement.'
               else
                 'Décision limitée aux propositions affichées ; aucun futur remplacement implicite.'
               end
      Rule.new(key: "sourced_#{field}_#{mode}", version: 1, axis: 'metadata',
               title: "#{mode == 'fill' ? 'Compléter' : 'Arbitrer'} : #{label(field)}",
               proposal: 'Appliquer les propositions documentées avec identité, justification et sources consultables.',
               limits: limits, recurring: mode == 'fill')
    end

    def self.copy_preference?(key)
      [PREFERENCE.key, MANUAL_COPY.key].include?(key)
    end

    def self.applicable?(item)
      return item.payload['manual_review'].present? if item.rule_key == MANUAL_COPY.key
      return item.payload.fetch('operations').any? if item.rule_key == SOURCED_STRUCTURE.key

      item.rule_key != PREFERENCE.key || item.payload.dig('comparison', 'eligible') == true
    end

    def self.fetch(key)
      all.find { |rule| rule.key == key } || raise(ArgumentError, 'Famille inconnue')
    end

    def self.label(field)
      { 'year' => 'année de référence', 'abstract' => 'résumé', 'country_id' => 'pays',
        'language_version_id' => 'langue de la fiche', 'genres' => 'genres' }.fetch(field)
    end
  end
end
