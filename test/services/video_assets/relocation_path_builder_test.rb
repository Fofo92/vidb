# frozen_string_literal: true

require 'test_helper'

class RelocationPathBuilderTest < ActiveSupport::TestCase
  StubRecord = Struct.new(:french_title, :original_title, :year, :seen, keyword_init: true) do
    def record_kind_standalone_video? = true
    def is_seen? = seen
  end

  test 'builds canonical path for 355' do
    record = StubRecord.new(french_title: '355', original_title: 'The 355', year: 2022, seen: false)
    assert_equal '/videos/Films/Espionnage/355 (The 355) (2022).mkv',
                 VideoAssets::RelocationPathBuilder.new.call(record: record, genres: ['Espionnage'])
  end

  test 'adds watched prefix' do
    record = StubRecord.new(french_title: '355', original_title: 'The 355', year: 2022, seen: true)
    assert_match %r{/\[\*\] 355 \(The 355\) \(2022\)\.mkv\z},
                 VideoAssets::RelocationPathBuilder.new.call(record: record, genres: ['Espionnage'])
  end

  test 'rejects unsafe genre' do
    record = StubRecord.new(french_title: '355', original_title: 'The 355', year: 2022)
    assert_raises(ArgumentError) do
      VideoAssets::RelocationPathBuilder.new.call(record: record, genres: ['../outside'])
    end
  end
end
