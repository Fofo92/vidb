require 'json'

module VideoAssets
  class EpisodePrefixJournal
    def initialize(path)
      @path = Pathname.new(path)
    end

    def open
      validate_parent!
      File.open(@path, File::RDWR | File::CREAT | File::NOFOLLOW, 0o600) do |file|
        validate_file!(file)
        raise ArgumentError, 'Un renommage est déjà en cours' unless file.flock(File::LOCK_EX | File::LOCK_NB)

        @file = file
        @events = file.each_line.map { |line| JSON.parse(line) }
        yield self
      end
    end

    def prepare
      return @events.first.fetch('plan') unless @events.empty?

      plan = yield
      append('prepared', 'plan' => plan)
      plan
    end

    def completed?(source)
      @events.any? { |event| event['event'] == 'completed' && event['source'] == source }
    end

    def append(event, details)
      row = details.merge('event' => event, 'at' => Time.now.utc.iso8601(6))
      @file.seek(0, IO::SEEK_END)
      @file.write("#{JSON.generate(row)}\n")
      @file.flush
      @file.fsync
      File.open(@path.dirname, File::RDONLY | File::NOFOLLOW, &:fsync)
      @events << row
    end

    private

    def validate_parent!
      parent = @path.dirname
      unless @path.absolute? && @path == @path.cleanpath
        raise ArgumentError,
              'Chemin absolu canonique de journal requis'
      end
      raise ArgumentError, 'Parent du journal introuvable ou symbolique' unless parent.parent.realpath == parent.parent

      Dir.mkdir(parent, 0o700) unless parent.exist?
      return if private_parent?(parent)

      raise ArgumentError, 'Répertoire de journal privé et sans lien symbolique requis'
    end

    def private_parent?(parent)
      stat = File.lstat(parent)
      stat.directory? && parent.realpath == parent && stat.uid == Process.uid && stat.mode.nobits?(0o077)
    end

    def validate_file!(file)
      stat = file.stat
      return if stat.file? && stat.uid == Process.uid && stat.mode.nobits?(0o077) && stat.size < 4_194_304

      raise ArgumentError, 'Journal privé régulier de moins de 4 Mio requis'
    end
  end
end
