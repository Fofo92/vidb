require "test_helper"
require "minitest/mock"

module Tv
  class XmltvImporterFailureTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @path = file_fixture(
        "tv/invalid_interval_guide.xml"
      )
    end

    test "records a failed attempt without persisting guide content" do
      error = assert_raises(XmltvReader::InvalidDocument) do
        XmltvImporter.new(
          guide_source: @source,
          path: @path
        ).call
      end

      assert_equal 1, @source.guide_imports.count

      failed_import = @source.guide_imports.first!

      assert failed_import.status_failed?
      assert failed_import.finished_at
      assert_match(/fin doit être postérieure/, error.message)
      assert_match(/fin doit être postérieure/,
                   failed_import.error_message)
      assert_not GuideChannel.exists?(guide_source_id: @source.id)
      assert_empty failed_import.guide_import_channels
      assert_empty failed_import.broadcast_observations
    end

    test "rolls back partial guide content before recording failure" do
      path = file_fixture("tv/minimal_guide.xml")
      persister = Object.new
      persister.define_singleton_method(:call) do
        raise "échec simulé pendant les observations"
      end

      error = assert_raises(RuntimeError) do
        XmltvImportObservationPersister.stub(
          :new,
          ->(*) { persister }
        ) do
          XmltvImporter.new(guide_source: @source, path: path).call
        end
      end

      assert_match(/échec simulé/, error.message)
      assert_equal 1, @source.guide_imports.count

      failed_import = @source.guide_imports.first!

      assert failed_import.status_failed?
      assert_match(/échec simulé/, failed_import.error_message)
      assert_not GuideChannel.exists?(guide_source_id: @source.id)
      assert_empty failed_import.guide_import_channels
      assert_empty failed_import.broadcast_observations
    end
  end
end
