#!/usr/bin/env ruby

require "minitest/autorun"
require "json"
require_relative "storefront_package"

class StorefrontPackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  METADATA_PATH = File.join(ROOT, "metadata", "en-GB-storefront.json")
  OVERLAYS_PATH = File.join(ROOT, "screenshots", "en-GB-overlays.json")

  def test_package_is_one_additive_en_gb_record_with_immutable_en_us_control
    result = StorefrontPackage.validate(root: ROOT)

    assert_empty result.errors
    assert_equal ["en-GB"], result.added_locales
    assert_equal(
      "d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d",
      result.control_sha256
    )
  end

  def test_rejects_metadata_that_exceeds_apple_unicode_character_limits
    metadata = JSON.parse(File.read(METADATA_PATH))
    metadata.fetch("drafts").find { |draft| draft.fetch("lane") == "en-GB" }
      .fetch("appInfo")["name"] = "é" * 31

    result = StorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes result.errors, "en-GB name is 31 characters; limit is 30"
  end

  def test_rejects_keyword_hygiene_errors_and_lost_british_search_intent
    metadata = JSON.parse(File.read(METADATA_PATH))
    draft = metadata.fetch("drafts").find { |candidate| candidate.fetch("lane") == "en-GB" }
    draft.fetch("appInfo")["name"] = "Pillie Routine Reminder"
    draft.fetch("versionLocalization")["keywords"] = "contraception,,Contraception,pillie"

    result = StorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes result.errors, "en-GB keywords contain an empty token"
    assert_includes result.errors, "en-GB keywords contain a duplicate token"
    assert_includes result.errors, "en-GB keywords contain the app name"
    assert_includes result.errors, "en-GB name must preserve “birth control reminder”"
  end

  def test_rejects_guarantee_efficacy_and_protection_claims
    metadata = JSON.parse(File.read(METADATA_PATH))
    draft = metadata.fetch("drafts").find { |candidate| candidate.fetch("lane") == "en-GB" }
    draft.fetch("versionLocalization")["description"] =
      "Guaranteed to prevent pregnancy so you always stay protected."

    result = StorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes result.errors, "en-GB copy contains prohibited guarantee language"
    assert_includes result.errors, "en-GB copy contains prohibited contraceptive-efficacy language"
    assert_includes result.errors, "en-GB copy contains prohibited always/stay-protected language"
  end

  def test_preview_is_additive_en_gb_only_and_cannot_target_en_us
    valid = StorefrontPackage.validate(root: ROOT)

    assert_includes valid.preview, "## Add en-GB"
    assert_includes valid.preview, "+ App Info locale: en-GB"
    refute_match(/^[~-]/, valid.preview)

    metadata = JSON.parse(File.read(METADATA_PATH))
    metadata.fetch("drafts").find { |draft| draft.fetch("lane") == "en-GB" }["ascLocale"] = "en-US"
    invalid = StorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes invalid.errors, "storefront package cannot target en-US"
    assert_nil invalid.preview
  end

  def test_rejects_incomplete_unordered_or_overlong_screenshot_overlays
    overlays = JSON.parse(File.read(OVERLAYS_PATH))
    en_gb = overlays.fetch("locales").find { |locale| locale.fetch("lane") == "en-GB" }
    en_gb.fetch("overlays").pop
    en_gb.fetch("overlays").reverse!
    en_gb.fetch("overlays").first["headline"] = "H" * 49
    en_gb.fetch("overlays").first["supporting"] = "S" * 81

    result = StorefrontPackage.validate(root: ROOT, overlays: overlays)

    assert_includes result.errors, "en-GB screenshots must contain exactly five overlays"
    assert_includes result.errors, "en-GB screenshot positions must be ordered 1 through 5"
    assert_includes result.errors, "en-GB screenshot 4 headline is 49 characters; limit is 48"
    assert_includes result.errors, "en-GB screenshot 4 supporting copy is 81 characters; limit is 80"
  end

  def test_rejects_drift_from_approved_en_gb_search_fields
    metadata = JSON.parse(File.read(METADATA_PATH))
    draft = metadata.fetch("drafts").fetch(0)
    draft.fetch("appInfo")["name"] = "Pillie: Contraception Reminder"
    draft.fetch("appInfo")["subtitle"] = "Daily Routine Reminder"
    draft.fetch("versionLocalization")["keywords"] =
      "contraception,contraceptive,medication,alarm,combined,mini,refill,cycle,missed,dose,tracker"

    result = StorefrontPackage.validate(root: ROOT, metadata: metadata)

    assert_includes result.errors, "en-GB name differs from the approved copy"
    assert_includes result.errors, "en-GB subtitle differs from the approved copy"
    assert_includes result.errors, "en-GB keywords differ from the approved copy"
  end
end
