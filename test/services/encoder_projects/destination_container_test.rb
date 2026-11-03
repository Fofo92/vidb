require 'test_helper'

class EncoderProjects::DestinationContainerTest < ActiveSupport::TestCase
  Parent = Struct.new(:attributes, :effective_countries) do
    def record_kind
      attributes.fetch('record_kind')
    end
  end
  Work = Struct.new(:parent, :standalone) do
    def record_kind_standalone_video?
      standalone
    end
  end

  test 'an existing film passes its collection titles and countries' do
    country = Struct.new(:long_name).new('France')
    parent = Parent.new({ 'french_title' => 'Collection', 'original_title' => 'Original',
                          'record_kind' => 'collection' }, [country])
    metadata = EncoderProjects::DestinationContainer.call(Work.new(parent, true))
    assert_equal 'Collection', metadata.dig('destination_container', 'french_title')
    assert_equal ['France'], metadata.dig('destination_container', 'countries')
    assert_equal 'Original', metadata.dig('destination_container', 'original_title')
  end

  test 'a documentary directly inside a series passes the series' do
    parent = Parent.new({ 'french_title' => 'La science', 'record_kind' => 'series' }, [])
    metadata = EncoderProjects::DestinationContainer.call(Work.new(parent, true))
    assert_equal 'La science', metadata.dig('destination_container', 'french_title')
  end

  test 'an independent work or an episode keeps its existing placement rules' do
    assert_empty EncoderProjects::DestinationContainer.call(Work.new(nil, true))
    assert_empty EncoderProjects::DestinationContainer.call(Work.new(nil, false))
    parent = Parent.new({ 'record_kind' => 'season' }, [])
    assert_empty EncoderProjects::DestinationContainer.call(Work.new(parent, true))
  end
end
