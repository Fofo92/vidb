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
    FIELDS = %w[year abstract country_id language_version_id genres].freeze

    def self.all
      [STRUCTURE, DISK] + FIELDS.flat_map do |field|
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

    def self.fetch(key)
      all.find { |rule| rule.key == key } || raise(ArgumentError, 'Famille inconnue')
    end

    def self.label(field)
      { 'year' => 'année de référence', 'abstract' => 'résumé', 'country_id' => 'pays',
        'language_version_id' => 'langue de la fiche', 'genres' => 'genres' }.fetch(field)
    end
  end
end
