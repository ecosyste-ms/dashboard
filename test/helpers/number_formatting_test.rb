require 'test_helper'

class NumberFormattingTest < ActionView::TestCase
  include ActionView::Helpers::NumberHelper

  test "number_to_human uses K for thousands" do
    assert_equal "1.5K", number_to_human(1500)
    assert_equal "2K", number_to_human(2000)
  end

  test "number_to_human uses M for millions" do
    assert_equal "1.5M", number_to_human(1500000)
    assert_equal "2M", number_to_human(2000000)
  end

  test "number_to_human uses B for billions" do
    assert_equal "1.2B", number_to_human(1200000000)
    assert_equal "3B", number_to_human(3000000000)
  end

  test "number_to_human respects precision option" do
    assert_equal "1M", number_to_human(1234567, precision: 1)
    assert_equal "1.2M", number_to_human(1234567, precision: 2)
  end

  test "number_to_human handles small numbers" do
    assert_equal "500", number_to_human(500)
    assert_equal "99", number_to_human(99)
  end
end