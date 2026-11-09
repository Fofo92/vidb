# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'securerandom'

module VideoAssets
  # Private recovery snapshot outside the catalogue and outside the media library.
  class CopyReferenceBackup
    FORMAT = 'vidb.copy_reference_backup'
    MAX_BYTES = 32 * 1024 * 1024

    def self.directory
      return '/srv/vidb/shared/copy-reference-backups' if Rails.env.production?

      Rails.root.join('tmp/copy-reference-backups')
    end

    def initialize(directory: self.class.directory)
      @directory = Pathname.new(directory).expand_path
    end

    def write(assets, user:)
      prepare_directory
      payload = snapshot(assets, user)
      text = JSON.pretty_generate('data' => payload, 'sha256' => Digest::SHA256.hexdigest(JSON.generate(payload)))
      raise ArgumentError, 'Sauvegarde trop volumineuse : nettoyage annulé.' if text.bytesize > MAX_BYTES

      path = @directory.join("#{Time.current.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.uuid}.json")
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| persist(file, text) }
      File.open(@directory, File::RDONLY, &:fsync)
      path.to_s
    end

    def self.read(path)
      text = File.open(path, File::RDONLY | File::NOFOLLOW) { |file| file.read(MAX_BYTES + 1) }
      raise ArgumentError, 'Sauvegarde trop volumineuse.' if text.bytesize > MAX_BYTES

      envelope = JSON.parse(text)
      data = envelope.fetch('data')
      valid = data['format'] == FORMAT && data['version'] == 1 && data['assets'].is_a?(Array)
      valid &&= envelope['sha256'] == Digest::SHA256.hexdigest(JSON.generate(data))
      raise ArgumentError, 'Sauvegarde incompatible ou altérée.' unless valid

      data
    end

    private

    def prepare_directory
      FileUtils.mkdir_p(@directory, mode: 0o700)
      stat = @directory.stat
      valid = @directory.realpath == @directory && stat.uid == Process.uid && stat.mode.nobits?(0o077)
      raise ArgumentError, 'Le dossier de sauvegarde doit être privé et sans lien symbolique.' unless valid
    end

    def attributes(record)
      record.attributes.transform_values { |value| value.is_a?(Time) ? value.iso8601(9) : value }
    end

    def snapshot(assets, user)
      { 'format' => FORMAT, 'version' => 1, 'created_at' => Time.current.iso8601(9), 'user_id' => user&.id,
        'purpose' => 'before_reference_cleanup', 'assets' => assets.map { |asset| attributes(asset) },
        'records' => assets.map(&:record).uniq(&:id).map { |record| attributes(record) } }
    end

    def persist(file, text)
      file.write(text)
      file.flush
      file.fsync
    end
  end
end
