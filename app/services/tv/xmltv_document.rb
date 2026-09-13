module Tv
  XmltvDocument = Data.define(
    :source_info_name,
    :source_info_url,
    :generator_info_name,
    :generator_info_url,
    :channels,
    :programmes,
    :duplicate_programme_count
  )
end
