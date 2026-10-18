module VideoAssets
  class EpisodePrefixPlan
    def initialize(root:, directory:, series_title:)
      @root = Pathname.new(root).cleanpath
      @directory = Pathname.new(directory).cleanpath
      @series_title = series_title
    end

    def call
      validate_directory!
      operations = Dir.glob(@directory.join('**/*').to_s).filter_map { |path| operation(path) }
      raise ArgumentError, 'Deux fichiers proposent la même destination' unless
        operations.map { |operation| operation.fetch('target') }.uniq.size == operations.size

      { 'format' => 'vidb.unlinked_episode_prefix_rename', 'version' => 1, 'directory' => @directory.to_s,
        'series_title' => @series_title, 'operations' => operations }
    end

    private

    def validate_directory!
      valid = @root.absolute? && @directory.absolute? && @directory.to_s.start_with?("#{@root}/") &&
              @directory.directory? && @directory.realpath == @directory && @series_title.present?
      raise ArgumentError, 'Répertoire canonique de série requis sous la racine vidéo' unless valid
    end

    def operation(path)
      match = parse_name(File.basename(path))
      return unless match
      unless File.lstat(path).file? && File.realpath(path) == path
        raise ArgumentError, 'Fichier ou répertoire symbolique exclu'
      end

      target = target(path, match)
      validate_file!(path, target)
      { 'source' => path, 'target' => target,
        'identity' => RelocationFileIdentity.call(File.lstat(path)).stringify_keys }
    end

    def parse_name(name)
      return unless name.match?(/\A#{Regexp.escape(@series_title)}\s+/i) &&
                    File.extname(name).match?(/\A\.(?:avi|mkv|m4v|mp4)\z/i)

      match = name.match(/\A#{Regexp.escape(@series_title)}\s+S(\d+)\s*E(\d+)\s*[-–—]\s*(.+)(\.(?:avi|mkv|m4v|mp4))\z/i)
      return match if match && EpisodeNumber.call(name)[:number]

      raise ArgumentError, "Numérotation absente ou ambiguë : #{name}"
    end

    def target(path, match)
      values = { season: match[1].to_i, episode: match[2].to_i, title: match[3], extension: match[4] }
      name = format('S%<season>02d E%<episode>02d - %<title>s%<extension>s', values)
      File.join(File.dirname(path), name)
    end

    def validate_file!(source, target)
      raise ArgumentError, "Destination occupée : #{target}" if File.exist?(target) || File.symlink?(target)
      raise ArgumentError, 'Plusieurs numéros d’épisode dans le nom' unless
        EpisodeNumber.call(File.basename(source))[:number]

      paths = [source, target]
      if VideoAsset.where(last_known_path: paths).where.not(status: 'deleted').exists?
        raise ArgumentError, 'Copie déjà suivie en base : déplacement avec mise à jour SQL requis'
      end

      stem = source.delete_suffix(File.extname(source))
      return unless %w[json srt ass sub idx mlt].any? { |extension| File.exist?("#{stem}.#{extension}") }

      raise ArgumentError, "Fichier compagnon à traiter avec la vidéo : #{source}"
    end
  end
end
