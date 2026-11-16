# frozen_string_literal: true

module VideoAssets
  class ConditionConventionPlan
    FORMAT = 'vidb.copy_condition_convention'

    def self.fingerprint(asset)
      ReconciliationWorkbench::Snapshot.digest(
        asset.attributes.slice('id', 'record_id', 'last_known_path', 'condition_details')
      )
    end

    def self.digest(changes)
      ReconciliationWorkbench::Snapshot.digest(changes)
    end

    def self.proposal(asset)
      DefaultConditionDocument.for_asset(asset)
    end

    def call
      result = { 'format' => FORMAT, 'version' => 1, 'mode' => 'preview',
                 'counts' => Hash.new(0), 'changes' => [], 'needs_review' => [] }
      VideoAsset.includes(:record).find_each { |asset| classify(asset, result) }
      result.merge('plan_digest' => self.class.digest(result.fetch('changes')))
    end

    private

    def classify(asset, result)
      proposal = self.class.proposal(asset)
      status = classification(asset, proposal)
      result['counts'][status] += 1
      result['needs_review'] << identity(asset) if status == 'needs_review'
      return unless status == 'proposed'

      result['changes'] << identity(asset).merge('before_digest' => self.class.fingerprint(asset),
                                                 'after' => proposal)
    end

    def identity(asset)
      { 'video_asset_id' => asset.id, 'record_id' => asset.record_id, 'path' => asset.last_known_path }
    end

    def classification(asset, proposal)
      return 'needs_review' if proposal.nil?

      proposal == asset.condition_details ? 'preserved' : 'proposed'
    end
  end
end
