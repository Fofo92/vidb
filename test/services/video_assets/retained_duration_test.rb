require 'test_helper'

module VideoAssets
  class RetainedDurationTest < ActiveSupport::TestCase
    test 'explicit minute and second notations and hour minute notations are exact' do
      { "41'" => 2460, '41 min' => 2460, "39'31" => 2371, '39′31″' => 2371,
        "0'31" => 31, '1h09' => 4140, '1h' => 3600, '24h' => 86_400 }.each do |text, seconds|
        assert_equal seconds, RetainedDuration.parse(text), text
      end
    end

    test 'ambiguous or out of range values are rejected' do
      [nil, '', '41', "39'60", '1h60', '25h', "0'", "1440'01", '-1 min'].each do |text|
        assert_nil RetainedDuration.parse(text), text.inspect
      end
    end

    test 'form accepts a seconds only duration and preserves empty unknown duration' do
      assert_equal 31, RetainedDuration.from_form(minutes: '', seconds: '31')
      assert_equal 2460, RetainedDuration.from_form(minutes: '41', seconds: '')
      assert_nil RetainedDuration.from_form(minutes: '', seconds: '')
      [['-1', '31'], ['1', '-1'], ['1', '60'], ['0', '0'], ['1440', '1']].each do |minutes, seconds|
        assert_raises(ArgumentError) { RetainedDuration.from_form(minutes: minutes, seconds: seconds) }
      end
    end
  end
end
