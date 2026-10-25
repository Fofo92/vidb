module EncoderProjects
  class SeriesPreview
    Reference = Struct.new(:id)
    Scope = Struct.new(:ids) do
      def select(*) = ids
    end
    Links = Struct.new(:id) do
      def where(**) = self
      def distinct = self
      def limit(*) = self
      def pluck(*) = [id].compact
    end

    def initialize(data)
      @data = data
    end

    def id = "tmdb:#{@data.fetch('tmdb_id')}"
    def french_title = @data.fetch('french_title')
    def original_title = @data['original_title'].to_s
    def year = @data['year']
    def subtree = Scope.new([])
    def effective_genders = @data.fetch('gender_ids', []).map { |id| Reference.new(id) }
    def effective_countries = @data.fetch('country_ids', []).map { |id| Reference.new(id) }
  end
end
