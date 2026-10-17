# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'

module ReclassificationFixture
  def self.included(base)
    base.class_eval do
      self.use_transactional_tests = false

      setup do
        @root = Dir.mktmpdir('vidb-reclassification-', '/tmp')
        @old = Gender.create!(name: 'RC_TEST_OLD')
        @new = Gender.create!(name: 'RC_TEST_NEW')
        @owned_genres = [@old, @new]
        @language = LanguageVersion.create!(short_name: 'RC_TEST', long_name: 'Reclassification test')
        @record = Record.create!(french_title: 'Reclassification test', year: 2000,
                                 record_kind: 'standalone_video', language_version: @language)
        @record.genders = [@old]
        @record.update_columns(genre_provenance: {})
        @source = File.join(@root, 'Films', @old.name, 'old.mkv')
        FileUtils.mkdir_p(File.dirname(@source))
        File.binwrite(@source, 'fixture')
        @asset = VideoAsset.create!(record: @record, status: 'present', last_known_path: @source,
                                    byte_size: File.size(@source), language_version: @language,
                                    technical_details: { 'language_qualification' => { 'basis' => 'fixture' } })
        configure
      end

      teardown do
        @record&.video_assets&.destroy_all if @record&.persisted?
        @record&.destroy! if @record&.persisted?
        @owned_genres&.each { |genre| genre.destroy! if genre.persisted? }
        @language&.destroy! if @language&.persisted?
        FileUtils.remove_entry(@root) if @root && File.directory?(@root)
      end

    end
  end

  def configure(category: 'film', genres: [@new.name])
    @classification = { category: category, genres: genres,
                        evidence: { reason: 'Reviewed fixture.', sources: ['https://example.org/film'] } }
    @qualification = @classification.merge(
      operation_id: 'reclassification-fixture', expected: { genres: [@old.name], provenance: {} },
      record_snapshot: @record.reload.attributes.except('updated_at').as_json,
      copy_snapshot: @asset.reload.attributes.except('updated_at').as_json
    )
    @guard = -> { true }
    @planner = VideoAssets::ReclassificationPlanner.new(root: @root, classification: @classification, volume_guard: @guard)
    directory = category == 'documentary' ? File.join(@root, 'Documentaires') : File.join(@root, 'Films', genres.sort.join(', '))
    FileUtils.mkdir_p(directory)
    @plan = @planner.call(asset: @asset, genres: [@old.name])
    @target = @plan.fetch(:target)
    @renamer = ->(source:, target:, identity:) { File.rename(source, target) }
  end

  def executor
    VideoAssets::ReclassificationCommit.new(
      root: @root, planner: @planner, journal_directory: File.join(@root, 'journal'), volume_guard: @guard,
      file_rename: @renamer, qualification: @qualification
    )
  end

  def execute(authorized: true)
    executor.call(plan: @plan, asset: @asset, genres: [@old.name], authorized: authorized)
  end

  def journal
    path = File.join(@root, 'journal', "relocation-#{@record.id}-#{@asset.id}.jsonl")
    File.readlines(path).map { |line| JSON.parse(line) }
  end

end
