# frozen_string_literal: true

module VideoAssets
  # Read-only preview; a ready plan never authorizes execution.
  class RelocationPlanner
    def initialize(root: '/videos', builder: nil, volume_guard: nil)
      @root = Pathname.new(root).cleanpath
      @builder = builder || RelocationPathBuilder.new(root: root)
      @volume_guard = volume_guard || ReconciliationVolumeGuard.new(root: root)
    end

    def call(asset:, genres:)
      source = Pathname.new(asset.last_known_path.to_s).cleanpath
      target = Pathname.new(@builder.call(record: asset.record, genres: genres)).cleanpath
      checks = path_checks(source, target)
      stat = source_stat(source, checks)
      checks.merge!(file_checks(asset, source, stat))
      report(asset, source, target, checks, stat)
    end

    def recheck(plan:, asset:, genres:)
      current = call(asset: asset, genres: genres)
      current[:checks][:same_plan] = %i[asset_id record_id source target].all? { |key| current[key] == plan[key] }
      current[:checks][:identity_matches] = !current[:identity].nil? && current[:identity] == plan[:identity]
      current[:ready] = current[:checks].values.all?
      current
    end

    private

    def path_checks(source, target)
      { volume: volume_ok?, source_inside_root: inside_root?(source), target_inside_root: inside_root?(target),
        same_directory: source.dirname == target.dirname, source_mkv: source.extname.downcase == '.mkv',
        destination_free: !File.exist?(target) && !File.symlink?(target), different_path: source != target,
        no_symlink_ancestors: safe_ancestors?(source) && safe_ancestors?(target) }
    end

    def source_stat(source, checks)
      return unless checks[:source_inside_root] && checks[:no_symlink_ancestors] && File.exist?(source)

      File.lstat(source)
    end

    def file_checks(asset, source, stat)
      regular = !stat.nil? && stat.file?
      { source_regular: regular,
        size_matches: regular && !asset.byte_size.nil? && stat.size == asset.byte_size,
        no_adjacent_json: regular && no_adjacent_json?(source),
        single_present_copy: asset.record.video_assets.one?(&:status_present?) }
    end

    def no_adjacent_json?(source)
      stem = source.basename(source.extname).to_s
      Dir.glob(source.dirname.join('*.json').to_s).none? { |path| File.basename(path).start_with?(stem) }
    end

    def report(asset, source, target, checks, stat)
      { record_id: asset.record_id, asset_id: asset.id, source: source.to_s, target: target.to_s,
        checks: checks, ready: checks.values.all?,
        identity: checks[:source_regular] ? RelocationFileIdentity.call(stat) : nil,
        execution_authorized: false }
    end

    def safe_ancestors?(path)
      return false unless path.absolute?

      directory = path.dirname
      loop do
        return false unless File.lstat(directory).directory?
        break if directory.root?

        directory = directory.parent
      end
      true
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES
      false
    end

    def inside_root?(path)
      path.absolute? && path.to_s.start_with?("#{@root}/") && !path.each_filename.to_a.intersect?(%w[. ..])
    end

    def volume_ok?
      @volume_guard.call
      true
    rescue ArgumentError
      false
    end
  end
end
