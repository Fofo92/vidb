require 'uri'

module EncoderProjects
  # Explicit local lookup; does not infer an association from the title alone.
  class LocalRecordSearch
    LIMIT = 50

    def initialize(records: Record)
      @records = records
    end

    def call(query, host:)
      text = query.to_s.strip.first(300)
      id = record_id(text, host)
      return @records.where(id: id).to_a if id

      words = normalize(text).split
      return [] if words.empty?

      ids = matching_ids(words)
      @records.where(id: ids).order(:french_title, :id).to_a
    end

    private

    def normalize(text)
      text.to_s.parameterize(separator: ' ')
    end

    def record_id(text, host)
      return text.delete_prefix('#').to_i if text.match?(/\A#?\d+\z/)

      uri = URI.parse(text)
      return unless uri.host.nil? || (%w[http https].include?(uri.scheme) && uri.host == host)

      match = uri.path&.match(%r{\A/records/(\d+)/?\z})
      match[1].to_i if match
    rescue URI::InvalidURIError
      nil
    end

    def matching_ids(words)
      matches = []
      @records.select(:id, :french_title, :original_title).find_each do |record|
        titles = [record.french_title, record.original_title].map { |title| normalize(title) }
        matches << record.id if titles.any? { |title| words.all? { |word| title.include?(word) } }
        break if matches.size == LIMIT
      end
      matches
    end
  end
end
