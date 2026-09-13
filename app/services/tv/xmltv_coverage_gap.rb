module Tv
  XmltvCoverageGap = Data.define(
    :starts_at,
    :ends_at
  ) do
    def duration_seconds
      (ends_at - starts_at).to_i
    end
  end
end
