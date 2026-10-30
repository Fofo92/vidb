module Tv
  class LibraryWorkCandidates
    def initialize(records: Record)
      @records = records
    end

    def call(programmes)
      requests = programmes.select { |programme| programme.episode_numbers.empty? }
      return {} if requests.empty?

      index = title_index(requests.flat_map { |programme| programme_titles(programme) }.uniq)
      matches = requests.to_h { |programme| [programme.id, match(programme, index)] }.compact
      records = @records.where(id: matches.values.map(&:id).uniq).includes(:video_assets).index_by(&:id)
      matches.transform_values { |record| records.fetch(record.id) }
    end

    private

    def programme_titles(programme)
      programme.titles.filter_map { |entry| AcquiredEpisodeIdentity.normalize(entry['value']).presence }.uniq
    end

    def title_index(names)
      rows = @records.all.select(:id, :record_kind, :ancestry, :french_title, :original_title).to_a
      @parent_ids = rows.filter_map { |record| record.ancestry.to_s.split('/').last&.to_i }.uniq
      rows.each_with_object({}) do |record, index|
        (AcquiredEpisodeIdentity.titles(record) & names).each { |name| (index[name] ||= []) << record }
      end
    end

    def individual_work?(record)
      !%w[collection series season].include?(record.record_kind) && !@parent_ids.include?(record.id)
    end

    def match(programme, index)
      rows = programme_titles(programme).flat_map { |name| index.fetch(name, []) }.uniq(&:id)
      rows.first if rows.one? && individual_work?(rows.first)
    end
  end
end
