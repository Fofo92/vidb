# frozen_string_literal: true

module VideoAssets
  # Absence is checked without following symlinks or treating access failures as absence.
  class AbsentCopyPath
    def initialize(root: '/videos')
      @root = root
    end

    def call(path, &)
      valid = path.is_a?(String) && !path.include?("\0") && path.start_with?("#{@root}/")
      valid &&= Pathname.new(path).cleanpath.to_s == path && File.realpath(@root) == @root
      raise ArgumentError, 'Chemin hors du volume autorisé.' unless valid

      walk(path, &)
    end

    private

    def occupied_path(stat)
      return true if stat.file? && yield(stat)

      raise ArgumentError, 'Un fichier existe encore à ce chemin ; aucune copie de remplacement confirmée.'
    end

    def walk(path, &)
      current = @root
      Pathname.new(path.delete_prefix("#{@root}/")).each_filename do |name|
        current = File.join(current, name)
        return true if inspect_component(current, path, &)
      end
    rescue Errno::ENOENT
      true
    end

    def inspect_component(current, path, &)
      stat = File.lstat(current)
      raise ArgumentError, 'Lien symbolique à examiner : aucune suppression confirmée.' if stat.symlink?
      return occupied_path(stat, &) if current == path && block_given?
      raise ArgumentError, 'Un fichier existe encore à ce chemin.' if current == path
      raise ArgumentError, 'Un parent n’est pas un répertoire.' unless stat.directory?

      false
    end
  end
end
