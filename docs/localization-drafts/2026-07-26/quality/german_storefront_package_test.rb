# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "german_storefront_package"

class GermanStorefrontPackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_approved_draft_is_additive_german_only_and_within_limits
    result = GermanStorefrontPackage.validate(root: ROOT)

    assert_empty result.errors
    assert_equal ["de-DE"], result.added_locales
    assert_equal "Pillie: Pillen-Erinnerung", result.fields.fetch("name")
    assert_equal "Pille, Ring & Pflaster", result.fields.fetch("subtitle")
    assert_operator result.fields.fetch("name").length, :<=, 30
    assert_operator result.fields.fetch("subtitle").length, :<=, 30
    assert_operator result.fields.fetch("keywords").length, :<=, 100
  end

  def test_rejects_a_plan_that_targets_the_en_us_control
    metadata = JSON.parse(
      File.read(File.join(ROOT, "metadata", "de-DE-storefront.json"))
    )
    metadata.fetch("drafts").first["ascLocale"] = "en-US"

    result = GermanStorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes result.errors, "storefront package cannot target en-US"
  end
end
