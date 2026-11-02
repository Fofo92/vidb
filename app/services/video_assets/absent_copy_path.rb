# frozen_string_literal: true

module VideoAssets
  # Absence is checked without following symlinks or treating access failures as absence.
  class AbsentCopyPath
    def initialize(root: '/videos')
      @root = root
    end

    def call(path)
      valid = path.is_a?(String) && !path.include?("\0") && path.start_with?("#{@root}/")
      valid &&= Pathname.new(path).cleanpath.to_s == path && File.realpath(@root) == @root
      raise ArgumentError, 'Chemin hors du volume autorisé.' unless valid

      walk(path)
    end

    private

    def walk(path)
      current = @root
      Pathname.new(path.delete_prefix("#{@root}/")).each_filename do |name|
        current = File.join(current, name)
        stat = File.lstat(current)
        raise ArgumentError, 'Lien symbolique à examiner : aucune suppression confirmée.' if stat.symlink?
        raise ArgumentError, 'Un fichier existe encore à ce chemin.' if current == path
        raise ArgumentError, 'Un parent n’est pas un répertoire.' unless stat.directory?
      end
    rescue Errno::ENOENT
      true
    end
  end
end
