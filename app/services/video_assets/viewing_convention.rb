module VideoAssets
  module ViewingConvention
    DIRECTORIES = %w[_vus _vues vus vues].freeze

    def self.strip_prefix(value)
      value.to_s.sub(/\A\s*\[\*\]\s*/, '')
    end

    def self.seen_path?(path)
      path.split('/')[...-1].any? { |name| DIRECTORIES.include?(name.downcase) } ||
        File.basename(path).match?(/\A\s*\[\*\]/)
    end
  end
end
