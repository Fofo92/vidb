module DvdScansHelper
  def dvd_work_query(product_title)
    season = product_title.match(/\s+\((?:season|saison)\s+([0-9]+)(?:\s+int[ée]grale?)?\)(?=\s|\z)/i)
    return [product_title, nil] unless season

    [season.pre_match.strip.presence || product_title, season[1]]
  end
end
