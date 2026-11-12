# frozen_string_literal: true

module VideoAssets
  class ConditionUpdate
    class Stale < StandardError; end

    def self.fingerprint(asset)
      ReconciliationWorkbench::Snapshot.digest(asset.attributes)
    end

    def initialize(asset, attributes:, fingerprint:, user:)
      @asset = asset
      @attributes = attributes.stringify_keys
      @fingerprint = fingerprint
      @user = user
    end

    def call
      @asset.record.with_lock do
        @asset.with_lock do
          raise Stale, 'La copie a changé. Recharge la page avant de la qualifier.' unless
            self.class.fingerprint(@asset) == @fingerprint

          @asset.update!(condition_details: document)
        end
      end
      @asset
    end

    private

    def document
      before = @asset.effective_condition.deep_dup
      values = @attributes.slice('integrality', 'damage', 'retained_portion', 'note')
      values['retained_duration_seconds'] = RetainedDuration.from_form(
        minutes: @attributes['retained_duration_minutes'], seconds: @attributes['retained_duration_remainder']
      )
      values['needs_review'] = false
      event = { 'origin' => 'manual', 'user_id' => @user.id, 'at' => Time.current.iso8601(9),
                'before' => before.except('evidence'), 'after' => values.deep_dup }
      values.merge('evidence' => Array(before['evidence']) + [event])
    end
  end
end
