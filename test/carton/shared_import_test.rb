# frozen_string_literal: true

require_relative '../test_helper'

SHARED_DIR = File.expand_path('../fixtures/shared', __dir__)

class SharedImportTest < Minitest::Test
  def test_repeated_import_returns_the_same_export
    assert_same import("#{SHARED_DIR}/money"), import("#{SHARED_DIR}/money")
  end

  def test_relative_absolute_and_named_imports_share_one_load
    added = !$LOAD_PATH.include?(SHARED_DIR)
    $LOAD_PATH.unshift(SHARED_DIR) if added

    money = import_relative '../fixtures/shared/money'

    assert_same money, import("#{SHARED_DIR}/money.rb")
    assert_same money, import('money')
  ensure
    $LOAD_PATH.delete(SHARED_DIR) if added
  end

  def test_sibling_cartons_share_a_transitive_carton
    wallet = import "#{SHARED_DIR}/wallet"
    bank = import "#{SHARED_DIR}/bank"

    assert_same wallet::Money, bank::Money
    assert bank.deposit(wallet.pay(100))
  end

  def test_namespace_first_imported_by_a_carton_is_main_box_exports
    from_carton = import "#{SHARED_DIR}/units_user"
    units = import "#{SHARED_DIR}/units"

    assert_same from_carton::Units, units
    assert_kind_of Carton::Exports, units
  end

  def test_circular_import_raises
    error = assert_raises(RuntimeError) { import "#{SHARED_DIR}/cycle_a" }
    assert_match(/circular import: .*cycle_a\.rb/, error.message)
  end

  def test_failed_import_is_not_cached
    ENV['CARTON_FLAKY_FAIL'] = '1'
    assert_raises(RuntimeError) { import "#{SHARED_DIR}/flaky" }

    ENV.delete('CARTON_FLAKY_FAIL')
    assert_equal :loaded, import("#{SHARED_DIR}/flaky").status
  ensure
    ENV.delete('CARTON_FLAKY_FAIL')
  end

  def test_concurrent_imports_share_one_load
    threads = 4.times.map { Thread.new { import "#{SHARED_DIR}/wallet" } }

    assert_equal 1, threads.map(&:value).uniq(&:object_id).size
  end
end
