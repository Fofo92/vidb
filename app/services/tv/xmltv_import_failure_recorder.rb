module Tv
  class XmltvImportFailureRecorder
    def initialize(guide_source, document_sha256, document_byte_size, error)
      @guide_source = guide_source
      @document_sha256 = document_sha256
      @document_byte_size = document_byte_size
      @error = error
    end

    def call
      failed_at = Time.current

      @guide_source.guide_imports.create!(
        document_sha256: @document_sha256,
        document_byte_size: @document_byte_size,
        status: "failed",
        started_at: failed_at,
        finished_at: failed_at,
        error_message: error_message
      )
    end

    private

    def error_message
      "#{@error.class}: #{@error.message}"
    end
  end
end
