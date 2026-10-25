require 'test_helper'

class EncoderProjects::BindingTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @record = Record.create!(french_title: 'Œuvre identifiée', record_kind: 'standalone_video', language_version: language)
    @uuid = '4d013c0a-7b54-4a67-aef2-7e1af7f6d410'
    @binding = EncoderProjects::Binding.issue(@uuid, @record)
  end

  test 'a signed binding identifies the record without relying on a filename' do
    receipt = { 'project_id' => @uuid, 'vidb' => @binding }
    assert_equal @record, EncoderProjects::Binding.record_for(receipt)
  end

  test 'changed record or project identifiers cannot forge a binding' do
    [@binding.merge('record_id' => @record.id + 1), @binding.merge('binding_token' => 'forged')].each do |binding|
      assert_raises(ArgumentError) { EncoderProjects::Binding.record_for('project_id' => @uuid, 'vidb' => binding) }
    end
    assert_raises(ArgumentError) { EncoderProjects::Binding.record_for('project_id' => 'invalid', 'vidb' => @binding) }
  end

  test 'legacy receipts carry no implicit project binding' do
    assert_nil EncoderProjects::Binding.record_for({})
  end

  test 'unborn or missing outputs are not needed for validating a project request' do
    request = EncoderProjects::ProjectRequest.new('project_id' => @uuid,
      'project_path' => '/videos/Film.json', 'output_path' => '/videos/Film.mkv', 'source_paths' => [])
    assert_equal @uuid, request.project_id
    assert_equal 0, VideoAsset.count
  end
end
