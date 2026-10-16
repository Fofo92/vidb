# frozen_string_literal: true

module VideoAssets
  class RelocationTrialState
    def initialize(prepared, observations)
      @prepared = prepared
      @source = observations.fetch(:source)
      @target = observations.fetch(:target)
      @database = observations.fetch(:database)
      @target_claimed = observations.fetch(:target_claimed_by_other_asset)
    end

    def call
      return :conflict unless valid_database?
      return :conflict if @target_claimed
      return :consistent_source if source_ready?
      return :conflict unless target_ready?
      return :consistent_target if @database[:path] == @prepared['target']

      @database[:path] == @prepared['source'] ? :database_update_pending : :conflict
    end

    private

    def valid_database?
      @database && @database[:record_id] == @prepared['record_id'] && @database[:status] == 'present'
    end

    def source_ready?
      @source[:identity_matches] && @target[:state] == :missing && @database[:path] == @prepared['source']
    end

    def target_ready?
      @source[:state] == :missing && @target[:identity_matches]
    end
  end
end
