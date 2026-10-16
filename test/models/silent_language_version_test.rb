# frozen_string_literal: true

require 'test_helper'

class SilentLanguageVersionTest < ActiveSupport::TestCase
  test 'recognizes the silent code and an existing Muet label' do
    assert LanguageVersion.new(short_name: 'MUET', long_name: 'Film muet').silent?
    assert LanguageVersion.new(short_name: 'M', long_name: 'Muet').silent?
    assert_not LanguageVersion.new(short_name: 'VF', long_name: 'Version française').silent?
    assert_not LanguageVersion.new.silent?
  end
end
