module Tv
  class ApplicationRecord < ::ApplicationRecord
    self.abstract_class = true
    self.table_name_prefix = "tv_"
  end
end
