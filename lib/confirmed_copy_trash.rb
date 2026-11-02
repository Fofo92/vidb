# frozen_string_literal: true

require 'digest'
require 'json'
require 'fileutils'

# Runs as the owner of the encoder queue, never as root or inside the Rails process.
module ConfirmedCopyTrash
  class Error < StandardError; end

  class Journal
    def initialize(registry)
      @registry = registry
    end

    def prepare(path, operation)
      root = File.join(File.dirname(path), '.video_encoder_trash')
      raise Error, 'Corbeille symbolique interdite.' if File.symlink?(root)

      FileUtils.mkdir_p(root, mode: 0o700)
      directory = File.join(root, operation)
      raise Error, 'Entrée de corbeille symbolique interdite.' if File.symlink?(directory)

      FileUtils.mkdir_p(directory, mode: 0o700)
      @registry.add(root)
      manifest(directory, path)
      File.open(root, File::RDONLY, &:fsync)
      directory
    end

    def manifest(directory, path)
      expected = { path => File.join(directory, "0-#{File.basename(path)}") }
      target = File.join(directory, 'manifest.json')
      write_manifest(target, expected) unless File.exist?(target) || File.symlink?(target)
      valid = File.file?(target) && !File.symlink?(target) && File.size(target) < 16_384
      valid &&= JSON.parse(File.read(target)) == expected
      valid &&= (Dir.children(directory) - ['manifest.json', File.basename(expected.values.first)]).empty?
      raise Error, 'Manifeste de corbeille incohérent.' unless valid
    end

    def write_manifest(target, expected)
      File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(JSON.pretty_generate(expected))
        file.flush
        file.fsync
      end
    end
  end

  class Operation
    EXTENSIONS = %w[.mkv .m4v .mp4 .avi .mov .ts .m2t .m2ts .mpg .mpeg .webm].freeze
    Entry = Struct.new(:paths) { alias_method :entries, :paths }

    def initialize(database:, registry:, usage:, root: '/videos')
      @database = database
      @journal = Journal.new(registry)
      @usage = usage
      @root = File.realpath(root)
    end

    def call(request)
      path = checked_path(request.fetch('path'))
      @database.transaction(mode: :immediate) do
        case request.fetch('operation')
        when 'preview' then preview(path)
        when 'remove' then remove(path, request)
        else raise Error, 'Opération inconnue.'
        end
      end
    end

    private

    def checked_path(value)
      raise Error, 'Chemin invalide.' unless value.is_a?(String) && File.expand_path(value) == value

      parent = File.dirname(value)
      valid = parent.start_with?("#{@root}/") || parent == @root
      valid &&= File.realpath(parent) == parent && !value.split('/').include?('.video_encoder_trash')
      valid &&= EXTENSIONS.include?(File.extname(value).downcase)
      raise Error, 'Seuls les fichiers vidéo du volume /videos sont autorisés.' unless valid

      value
    end

    def identity(path)
      stat = File.lstat(path)
      raise Error, 'La copie doit être un fichier régulier, sans lien.' unless stat.file? && stat.nlink == 1

      [stat.dev, stat.ino, stat.size, stat.mtime.to_r.to_s, stat.ctime.to_r.to_s]
    end

    def token(path, signature)
      Digest::SHA256.hexdigest(JSON.generate([path, signature]))
    end

    def guard(paths)
      @database[:jobs].where(status: %w[running queued deferred]).each do |job|
        unless job[:project_path] && File.file?(job[:project_path])
          raise Error, 'Un projet actif est inaccessible : vérification de la file impossible.'
        end
      end
      @usage.validate(Entry.new(paths.to_h { |path| [path, path] }))
    end

    def preview(path)
      signature = identity(path)
      guard([path])
      { 'path' => path, 'identity' => signature, 'token' => token(path, signature) }
    end

    def remove(path, request)
      operation, signature = confirmed_request(path, request)

      directory = File.join(File.dirname(path), '.video_encoder_trash', operation)
      archived = File.join(directory, "0-#{File.basename(path)}")
      guard([path, archived])
      raise Error, 'Le fichier a changé depuis la confirmation.' if File.exist?(path) && identity(path) != signature

      @journal.prepare(path, operation)
      move(path, archived, signature)
      { 'path' => path, 'directory' => directory, 'archived' => archived, 'id' => operation }
    end

    def confirmed_request(path, request)
      operation = request.fetch('id')
      raise Error, 'Identifiant invalide.' unless operation.is_a?(String) &&
                                                  operation.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)

      signature = request.fetch('identity')
      raise Error, 'Confirmation invalide.' unless request['token'] == token(path, signature)

      [operation, signature]
    end

    def validate_archived(path, archived, signature)
      valid = !File.exist?(path) && !File.symlink?(path) && identity(archived).first(4) == signature.first(4)
      raise Error, 'La copie ou sa corbeille a changé.' unless valid
    end

    def move(path, archived, signature)
      if File.exist?(archived) || File.symlink?(archived)
        validate_archived(path, archived, signature)

        return
      end
      raise Error, 'Le fichier a changé depuis la confirmation.' unless identity(path) == signature

      File.rename(path, archived)
      File.open(File.dirname(path), File::RDONLY, &:fsync)
      File.open(File.dirname(archived), File::RDONLY, &:fsync)
      raise Error, 'Le fichier déplacé doit être examiné dans la corbeille.' unless
        identity(archived).first(4) == signature.first(4)
    end
  end
end
