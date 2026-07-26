# frozen_string_literal: true

require "digest"
require "json"

module StorefrontPackage
  Result = Struct.new(:errors, :added_locales, :control_sha256, :preview, keyword_init: true)
  CONTROL_SHA256 = "d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d"
  APPROVED_SEARCH_FIELDS = {
    "name" => "Pillie: Birth Control Reminder",
    "subtitle" => "Pill, Patch & Ring Reminder",
    "keywords" => "contraception,contraceptive,medication,alarm,combined,mini,refill,cycle,missed,dose,tracker,nuvaring"
  }.freeze

  module_function

  FIELD_LIMITS = {
    "name" => 30,
    "subtitle" => 30,
    "keywords" => 100,
    "description" => 4_000,
    "whatsNew" => 4_000
  }.freeze
  PROHIBITED_CLAIMS = {
    "guarantee" => /\bguarantee(?:d|s)?\b/i,
    "contraceptive-efficacy" => /\bprevent(?:s|ed|ing)? pregnancy\b/i,
    "always/stay-protected" => /\b(?:always|stay) protected\b/i
  }.freeze

  def validate(root:, metadata: nil, overlays: nil)
    control_path = File.join(root, "source", "en-US-control.json")
    drafts = metadata || JSON.parse(File.read(File.join(root, "metadata", "en-GB-storefront.json")))
    screenshot_drafts = overlays || JSON.parse(File.read(File.join(root, "screenshots", "en-GB-overlays.json")))
    en_gb_drafts = drafts.fetch("drafts").select { |draft| draft.fetch("lane") == "en-GB" }
    errors = []
    customer_copy = []
    control_sha256 = Digest::SHA256.file(control_path).hexdigest

    errors << "package must be additive-only" unless drafts.dig("policy", "additiveOnly") == true
    errors << "package must protect en-US" unless drafts.dig("policy", "doNotModifyLocale") == "en-US"
    errors << "package must contain exactly one en-GB record" unless en_gb_drafts.length == 1
    errors << "en-US control bytes changed" unless control_sha256 == CONTROL_SHA256
    en_gb_drafts.each do |draft|
      errors << "storefront package cannot target en-US" if draft.fetch("ascLocale") == "en-US"
      errors << "storefront package must target en-GB" unless draft.fetch("ascLocale") == "en-GB"
      fields = draft.fetch("appInfo").merge(draft.fetch("versionLocalization"))
      APPROVED_SEARCH_FIELDS.each do |field, approved_value|
        verb = field == "keywords" ? "differ" : "differs"
        errors << "en-GB #{field} #{verb} from the approved copy" unless fields.fetch(field) == approved_value
      end
      FIELD_LIMITS.each do |field, limit|
        length = fields.fetch(field).length
        errors << "en-GB #{field} is #{length} characters; limit is #{limit}" if length > limit
      end

      keywords = fields.fetch("keywords").split(",", -1).map(&:strip)
      errors << "en-GB keywords contain an empty token" if keywords.any?(&:empty?)
      errors << "en-GB keywords contain a duplicate token" unless keywords.map(&:downcase).uniq.length == keywords.length
      errors << "en-GB keywords contain the app name" if keywords.any? { |keyword| keyword.casecmp("pillie").zero? }
      unless fields.fetch("name").downcase.include?("birth control reminder")
        errors << "en-GB name must preserve “birth control reminder”"
      end

      customer_copy.concat(fields.values.compact)
    end

    en_gb_screenshot_lanes = screenshot_drafts.fetch("locales").select { |locale| locale.fetch("lane") == "en-GB" }
    errors << "screenshots must contain exactly one en-GB lane" unless en_gb_screenshot_lanes.length == 1
    en_gb_screenshot_lanes.each do |locale|
      frames = locale.fetch("overlays")
      errors << "en-GB screenshots must contain exactly five overlays" unless frames.length == 5
      errors << "en-GB screenshot positions must be ordered 1 through 5" unless frames.map { |frame| frame.fetch("position") } == [1, 2, 3, 4, 5]
      frames.each do |frame|
        position = frame.fetch("position")
        headline = frame.fetch("headline")
        supporting = frame.fetch("supporting")
        if headline.length > 48
          errors << "en-GB screenshot #{position} headline is #{headline.length} characters; limit is 48"
        end
        if supporting.length > 80
          errors << "en-GB screenshot #{position} supporting copy is #{supporting.length} characters; limit is 80"
        end
        customer_copy.concat([headline, supporting])
      end
    end

    review_text = customer_copy.join("\n")
    PROHIBITED_CLAIMS.each do |label, pattern|
      errors << "en-GB copy contains prohibited #{label} language" if review_text.match?(pattern)
    end

    Result.new(
      errors: errors,
      added_locales: en_gb_drafts.map { |draft| draft.fetch("ascLocale") },
      control_sha256: control_sha256,
      preview: errors.empty? ? build_preview(en_gb_drafts.fetch(0)) : nil
    )
  end

  def build_preview(draft)
    app_info = draft.fetch("appInfo")
    version = draft.fetch("versionLocalization")

    <<~MARKDOWN
      # App Store Connect dry-run preview

      ## Add en-GB

      + App Info locale: en-GB
      + Name: #{app_info.fetch("name")}
      + Subtitle: #{app_info.fetch("subtitle")}
      + Privacy policy URL: #{app_info.fetch("privacyPolicyUrl")}
      + Version Localization locale: en-GB
      + Keywords: #{version.fetch("keywords")}
      + Marketing URL: #{version.fetch("marketingUrl")}
      + Support URL: #{version.fetch("supportUrl")}
      + Promotional text: #{version.fetch("promotionalText") || "(none)"}
      + Description:

      #{version.fetch("description")}

      + What's New:

      #{version.fetch("whatsNew")}
    MARKDOWN
  end
end
