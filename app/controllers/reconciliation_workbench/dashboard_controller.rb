module ReconciliationWorkbench
  class DashboardController < ApplicationController
    def show
      @axis = params[:axis] == 'disk' ? 'disk' : 'metadata'
      @rules = Rules.all.select { |rule| rule.axis == @axis }
      @overview = VideoAssets::ReconciliationOverview.new.call
      @latest_run = ReconciliationRun.order(:id).last
    end

    def status
      @runs = ReconciliationRun.order(id: :desc).limit(10)
      render partial: 'reconciliation_workbench/status', locals: { runs: @runs }
    end

    def refresh
      queue('refresh')
    end

    def apply
      queue('apply')
    end

    def proposals
      upload = params.require(:proposals)
      text = upload.respond_to?(:read) ? upload.read(2_097_153) : upload.to_s
      raise ArgumentError, 'Document limité à 2 Mo' if text.bytesize > 2_097_152

      items = Proposals.new.call(JSON.parse(text))
      redirect_to reconciliation_workbench_path(axis: 'metadata'),
                  notice: "#{items.size} propositions sourcées ajoutées, sans application."
    rescue ArgumentError, KeyError, TypeError, JSON::ParserError, URI::InvalidURIError,
           ActiveRecord::RecordNotFound => e
      redirect_to reconciliation_workbench_path(axis: 'metadata'), alert: e.message
    end

    def stop
      run = ReconciliationRun.find(params.require(:run_id))
      run.update!(stop_requested: true) unless run.terminal?
      redirect_to reconciliation_workbench_path, notice: 'Arrêt demandé après l’opération en cours.'
    end

    def exceptions
      @category = params[:category].to_s
      source = JSON.parse(Planner.followup_path.read)
      summary = VideoAssets::BlockageSummary.new(followup: source).call
      @groups = exception_groups(summary)
      @total = @groups.sum { |group| group[:file_count] }
      @page = [params[:page].to_i, 1].max
      @groups = @groups.slice((@page - 1) * 30, 30) || []
    rescue Errno::ENOENT, JSON::ParserError => e
      redirect_to reconciliation_workbench_path, alert: e.message
    end

    private

    def exception_groups(summary)
      groups = summary[:groups].reject do |group|
        group[:category] == 'confirmed' || group[:category].start_with?('excluded_')
      end
      @category.present? ? groups.select { |group| group[:category] == @category } : groups
    end

    def queue(mode)
      if ReconciliationRun.where(status: %w[queued running]).exists?
        redirect_to reconciliation_workbench_path, notice: 'Une passe est déjà en attente ou en cours.'
      else
        ReconciliationRun.create!(mode: mode, user: current_user)
        redirect_to reconciliation_workbench_path, notice: 'Passe mise en attente ; le service la prendra en charge.'
      end
    end
  end
end
