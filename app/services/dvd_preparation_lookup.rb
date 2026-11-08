class DvdPreparationLookup
  def initialize(client: DvdBarcodeLookup.new)
    @client = client
  end

  def call(preparation)
    titles = @client.call(preparation.ean)
    preparation.update!(external_titles: titles, lookup_status: titles.any? ? "found" : "not_found",
                        lookup_checked_at: Time.current)
  rescue DvdBarcodeLookup::Error
    preparation.update!(lookup_status: "unavailable", lookup_checked_at: Time.current)
  end
end
