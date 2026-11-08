module EncoderProjects
  class DvdMenuCataloguesController < IdentificationsController
    def show
      ean = params[:ean]
      return head :bad_request unless DvdEdition.valid_ean?(ean)

      series = DvdEdition.find_by!(ean: ean).record
      return head :unprocessable_content unless series.record_kind_series?

      render json: DvdMenuCatalogue.new(series).call
    rescue ActiveRecord::RecordNotFound
      head :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_content
    end
  end
end
