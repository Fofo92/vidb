module Tv
  EpisodeAcquisition = Struct.new(:kind, :label, :description, :record_id, :paths, keyword_init: true)
end
