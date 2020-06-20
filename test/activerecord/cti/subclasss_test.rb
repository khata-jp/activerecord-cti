require 'test_helper'

class ActiveRecord::Cti::SubClassTest < ActiveSupport::TestCase
  TESTCASE_NAME = 'Ryan Giggs'
  TESTCASE_BIRTH_YEAR = 1973
  TESTCASE_POSITION_NAME = 'midfielder'
  TESTCASE_LICENCE_NAME = 'UEFA Pro'

  setup do
    Player.new(
      name: TESTCASE_NAME,
      birth_year: TESTCASE_BIRTH_YEAR,
      position_name: TESTCASE_POSITION_NAME
    ).save
  end

  test "test_basic_attributes" do
    assert_equal(Player.first.name, TESTCASE_NAME)
    assert_equal(Player.first.birth_year, TESTCASE_BIRTH_YEAR)
    assert_equal(Player.first.position_name, TESTCASE_POSITION_NAME)
  end

  test "test_find_by" do
    assert_equal(Player.find_by(name: TESTCASE_NAME).position_name, TESTCASE_POSITION_NAME)
  end

  test "test_where" do
    assert_equal(Player.where(name: TESTCASE_NAME).first.position_name, TESTCASE_POSITION_NAME)
  end

  test "test_convert" do
    player = Player.first
    assert_respond_to(player, :to_coach)

    coach = player.to_coach(licence_name: TESTCASE_LICENCE_NAME)
    assert_equal(coach.class, Coach)
    assert_equal(coach.licence_name, TESTCASE_LICENCE_NAME)

    coach.save
    assert_equal(Coach.find_by(name: TESTCASE_NAME).licence_name, TESTCASE_LICENCE_NAME)
  end

  teardown do
    Player.delete_all
    Coach.delete_all
  end
end
