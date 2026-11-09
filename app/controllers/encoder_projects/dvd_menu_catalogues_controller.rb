module EncoderProjects
  class DvdMenuCataloguesController < IdentificationsController
    def preparations
      entries = DvdPreparation.includes(dvd_edition: :record).order(last_scanned_at: :desc, id: :desc).limit(100)
      render json: { preparations: entries.map { |preparation| preparation_option(preparation) } }
    end

    def series
      query = params[:q].to_s.strip
      return head :bad_request unless query.length.between?(1, 300)

      records = LocalRecordSearch.new(records: Record.where(record_kind: 'series')).call(query, host: request.host)
      render json: { series: records.map { |record| series_option(record) } }
    end

    def show
      ean = request.path_parameters[:ean]
      return head :bad_request if ean && !DvdEdition.valid_ean?(ean)

      series = selected_series
      return head :unprocessable_content unless series.record_kind_series?

      render json: DvdMenuCatalogue.new(series).call
    rescue ActiveRecord::RecordNotFound
      head :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def select_episode
      raise ArgumentError, 'Demande de projet limitée à 64 Ko' if request.raw_post.bytesize > 65_536

      project = ProjectRequest.new(project_params).data
      record = Record.where(record_kind: 'episode').find(params[:record_id])
      url = @configuration.fetch('url')
      LocalRecordSelection.call(user: @operator, url: url, project: project, record: record)
      render json: Identification.new(user: @operator, url: url).call(project)
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def project_params
      params.require(:project).permit(:project_id, :project_path, :output_path, :language_hint, source_paths: []).to_h
    end

    def preparation_option(preparation)
      { id: preparation.id, title: preparation.display_title, announced_count: preparation.announced_content_count,
        series_ready: preparation.dvd_edition&.record&.record_kind_series? == true }
    end

    def selected_series
      return preparation_series if params[:preparation_id].present?
      return Record.where(record_kind: 'series').find(params[:series_id]) if params[:series_id].present?

      ean = params[:ean]
      raise ArgumentError, 'EAN-13 invalide' unless DvdEdition.valid_ean?(ean)

      DvdEdition.find_by!(ean: ean).record
    end

    def preparation_series
      preparation = DvdPreparation.find(params[:preparation_id])
      record = preparation.dvd_edition&.record
      return record if record&.record_kind_series?

      raise ArgumentError, "Associe la préparation n° #{preparation.id} à sa série dans DVD à préparer."
    end

    def series_option(record)
      { id: record.id, title: record.french_title.presence || record.original_title, year: record.year }
    end
  end
end
