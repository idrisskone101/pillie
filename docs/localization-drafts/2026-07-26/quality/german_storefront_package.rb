# frozen_string_literal: true

require "digest"
require "json"

module GermanStorefrontPackage
  Result = Struct.new(:errors, :added_locales, :fields, keyword_init: true)

  CONTROL_SHA256 = "d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d"
  FIELD_LIMITS = {
    "name" => 30,
    "subtitle" => 30,
    "keywords" => 100,
    "description" => 4_000,
    "whatsNew" => 4_000,
  }.freeze
  PROHIBITED_CLAIMS = {
    "guarantee" => /\bgarantier(?:t|en|te)\b/i,
    "contraceptive-efficacy" => /verhindert (?:eine |die )?schwangerschaft/i,
    "always-protected" => /immer geschützt/i,
  }.freeze

  module_function

  def validate(root:, metadata: nil)
    control_path = File.join(root, "source", "en-US-control.json")
    drafts = metadata || JSON.parse(
      File.read(File.join(root, "metadata", "de-DE-storefront.json"))
    )
    german_drafts = drafts.fetch("drafts").select do |draft|
      draft.fetch("lane") == "de-DE"
    end
    errors = []
    fields = {}

    errors << "package must be additive-only" unless drafts.dig("policy", "additiveOnly") == true
    errors << "package must protect en-US" unless drafts.dig("policy", "doNotModifyLocale") == "en-US"
    errors << "package must contain exactly one de-DE record" unless german_drafts.length == 1
    unless Digest::SHA256.file(control_path).hexdigest == CONTROL_SHA256
      errors << "en-US control bytes changed"
    end

    german_drafts.each do |draft|
      errors << "storefront package cannot target en-US" if draft.fetch("ascLocale") == "en-US"
      errors << "storefront package must target de-DE" unless draft.fetch("ascLocale") == "de-DE"
      fields = draft.fetch("appInfo").merge(draft.fetch("versionLocalization"))

      FIELD_LIMITS.each do |field, limit|
        length = fields.fetch(field).length
        errors << "de-DE #{field} is #{length} characters; limit is #{limit}" if length > limit
      end

      keywords = fields.fetch("keywords").split(",", -1).map(&:strip)
      errors << "de-DE keywords contain an empty token" if keywords.any?(&:empty?)
      unless keywords.map(&:downcase).uniq.length == keywords.length
        errors << "de-DE keywords contain a duplicate token"
      end
      if keywords.any? { |keyword| keyword.casecmp("pillie").zero? }
        errors << "de-DE keywords contain the app name"
      end

      review_text = fields.values.compact.join("\n")
      PROHIBITED_CLAIMS.each do |label, pattern|
        errors << "de-DE copy contains prohibited #{label} language" if review_text.match?(pattern)
      end
      unless review_text.match?(/\bSie\b/) && review_text.match?(/\bIhre/)
        errors << "de-DE storefront must use formal Sie address"
      end
    end

    Result.new(
      errors: errors,
      added_locales: german_drafts.map { |draft| draft.fetch("ascLocale") },
      fields: fields
    )
  end
end
