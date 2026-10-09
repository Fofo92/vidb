require "digest"

class RecordChildQualificationSnapshot
  def self.token(record)
    verifier.generate(fingerprint(record), purpose: "children:#{record.id}")
  end

  def self.matches?(record, token)
    verifier.verified(token, purpose: "children:#{record.id}") == fingerprint(record)
  end

  def self.verifier
    Rails.application.message_verifier("record-child-qualification")
  end

  def self.fingerprint(record)
    records = [record, *record.descendants.order(:id).to_a]
    values = records.sort_by(&:id).map do |item|
      [item.attributes, item.gender_ids.sort, item.country_ids.sort, item.medium_ids.sort,
       item.video_assets.order(:id).map(&:attributes)]
    end
    Digest::SHA256.hexdigest(values.to_json)
  end
end
