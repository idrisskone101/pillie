# frozen_string_literal: true

require "digest"
require "json"

ROOT = File.expand_path("..", __dir__)
METADATA_PATH = File.join(ROOT, "metadata", "de-DE-storefront.json")
APP_INFO_STRINGS_PATH = File.join(ROOT, "metadata", "app-info", "de-DE.strings")
VERSION_STRINGS_PATH = File.join(ROOT, "metadata", "version", "de-DE.strings")
CONTROL_SHA256 = "d1d4e3451b0b38d0cbbd327edd85fac25f1b5f35870b54e7594c9d054973fa9d"

FIELD_LIMITS = {
  "name" => 30,
  "subtitle" => 30,
  "keywords" => 100,
  "description" => 4_000,
  "whatsNew" => 4_000,
  "promotionalText" => 170,
}.freeze

APP_INFO_KEYS = %w[name subtitle privacyPolicyUrl].freeze
VERSION_KEYS = %w[description keywords marketingUrl supportUrl whatsNew promotionalText].freeze
INDEXED_APP_INFO_TOKENS = %w[pillie pille pillen erinnerung ring pflaster].freeze
PROHIBITED_CLAIMS = {
  "guaranteed-adherence" => /(?:garantiert|garantie|nie wieder vergessen)/i,
  "contraceptive-efficacy" => /verhindert (?:eine |die )?schwangerschaft/i,
  "always-protected" => /immer geschützt/i,
  "absolute-efficacy" => /100\s*%/i,
}.freeze

def parse_strings(path)
  contents = File.read(path)
  pairs = contents.scan(/"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;/)

  pairs.to_h do |raw_key, raw_value|
    [JSON.parse(%Q{"#{raw_key}"}), JSON.parse(%Q{"#{raw_value}"})]
  end
end

def assert(errors, condition, message)
  errors << message unless condition
end

metadata = JSON.parse(File.read(METADATA_PATH))
app_info = metadata.fetch("appInfo")
version = metadata.fetch("versionLocalization")
candidates = metadata.fetch("keywordCandidates")
keyword_research = metadata.fetch("keywordResearch")
errors = []

assert(errors, metadata.fetch("reviewStatus") == "READY_FOR_USER_REVIEW_REQUIRES_EXPLICIT_APPROVAL", "review status must be ready while preserving the explicit approval gate")
assert(errors, metadata.fetch("keywordStatus") == "FINAL_ASTRO_VALIDATED_REQUIRES_EXPLICIT_USER_APPROVAL", "keyword field must be Astro-validated while preserving the explicit approval gate")
assert(errors, metadata.dig("target", "locale") == "de-DE", "target locale must be de-DE")
assert(errors, metadata.dig("target", "scope") == "german-storefront-only", "scope must be German storefront only")
assert(errors, metadata.dig("target", "versionId") == "b1440d5c-9b53-4bc0-98ec-8b0f40de0dec", "live 2.0.6 version ID is missing or stale")
assert(errors, metadata.dig("target", "appInfoId") == "d03b4450-ab0c-45fd-94b7-3c36edb33b09", "live App Info ID is missing or stale")
assert(errors, metadata.dig("target", "liveVersionState") == "PREPARE_FOR_SUBMISSION", "live version is not recorded as editable")
assert(errors, metadata.dig("target", "liveAppInfoState") == "PREPARE_FOR_SUBMISSION", "live App Info is not recorded as editable")
assert(errors, metadata.dig("target", "liveDeDEAppInfoLocalization") == "ABSENT", "de-DE App Info delta must remain additive")
assert(errors, metadata.dig("target", "liveDeDEVersionLocalization") == "ABSENT", "de-DE Version delta must remain additive")
assert(errors, metadata.dig("policy", "doNotModifyLocale") == "en-US", "en-US must remain protected")
assert(errors, app_info.fetch("locale") == "de-DE", "App Info locale must be de-DE")
assert(errors, version.fetch("locale") == "de-DE", "Version Localization locale must be de-DE")

control_path = File.expand_path(metadata.fetch("sourceControl"), File.dirname(METADATA_PATH))
assert(errors, File.file?(control_path), "immutable en-US control fixture is missing")
if File.file?(control_path)
  assert(errors, Digest::SHA256.file(control_path).hexdigest == CONTROL_SHA256, "immutable en-US control bytes changed")
end

fields = app_info.merge(version)
FIELD_LIMITS.each do |field, limit|
  value = fields.fetch(field)
  assert(errors, value.is_a?(String) && !value.empty?, "#{field} must be a non-empty string")
  assert(errors, value.length <= limit, "#{field} is #{value.length} characters; limit is #{limit}")
end

keywords = version.fetch("keywords")
keyword_tokens = keywords.split(",", -1).map(&:strip)
assert(errors, keyword_tokens.none?(&:empty?), "keywords contain an empty token")
assert(errors, keyword_tokens.map(&:downcase).uniq.length == keyword_tokens.length, "keywords contain duplicate tokens")
assert(errors, (keyword_tokens.map(&:downcase) & INDEXED_APP_INFO_TOKENS).empty?, "keywords repeat an exact app-name or subtitle token")

assert(errors, candidates.length == 1, "package must contain exactly one locked keyword recommendation")
candidates.each do |candidate|
  candidate_value = candidate.fetch("value")
  assert(errors, candidate.fetch("characters") == candidate_value.length, "keyword candidate #{candidate.fetch("id")} character count is stale")
  assert(errors, candidate_value.length <= 100, "keyword candidate #{candidate.fetch("id")} exceeds 100 characters")
end
recommended = candidates.find { |candidate| candidate.fetch("status") == "recommended-final-astro" }
assert(errors, !recommended.nil?, "one keyword candidate must be the final Astro recommendation")
assert(errors, recommended&.fetch("value") == keywords, "Version Localization keywords must match the final Astro recommendation")

assert(errors, keyword_research.fetch("provider") == "Astro local MCP", "keyword research provider must be Astro local MCP")
assert(errors, keyword_research.fetch("market") == "Germany", "keyword research market must be Germany")
expected_signals = %w[pillenalarm].concat([
  "zyklus tracker",
  "medikamente",
  "medikamenten erinnerung",
  "tabletten erinnerung",
  "einnahme erinnerung",
  "antibabypille erinnerung",
])
assert(errors, keyword_research.fetch("signals").map { |signal| signal.fetch("term") } == expected_signals, "Astro Germany signal set is incomplete or reordered")
assert(errors, keyword_research.fetch("excludedSuggestions") == %w[nuvaring refill], "policy-sensitive Astro exclusions must remain explicit")

review_text = fields.values.grep(String).join("\n")
PROHIBITED_CLAIMS.each do |label, pattern|
  assert(errors, !review_text.match?(pattern), "copy contains prohibited #{label} language")
end
assert(errors, review_text.match?(/\bSie\b/) && review_text.match?(/\bIhre\b/), "storefront description must use formal Sie address")
assert(errors, !review_text.match?(/\b(?:du|dein(?:e|en|er|em|es)?)\b/i), "storefront copy mixes in informal du address")

%w[privacyPolicyUrl marketingUrl supportUrl].each do |field|
  assert(errors, fields.fetch(field).start_with?("https://"), "#{field} must use HTTPS")
end

app_info_strings = parse_strings(APP_INFO_STRINGS_PATH)
version_strings = parse_strings(VERSION_STRINGS_PATH)
assert(errors, app_info_strings.keys.sort == APP_INFO_KEYS.sort, "App Info .strings field set is incorrect")
assert(errors, version_strings.keys.sort == VERSION_KEYS.sort, "Version .strings field set is incorrect")
APP_INFO_KEYS.each do |field|
  assert(errors, app_info_strings[field] == app_info.fetch(field), "App Info .strings #{field} differs from canonical JSON")
end
VERSION_KEYS.each do |field|
  assert(errors, version_strings[field] == version.fetch(field), "Version .strings #{field} differs from canonical JSON")
end

if errors.empty?
  FIELD_LIMITS.each do |field, limit|
    puts "de-DE #{field}: #{fields.fetch(field).length}/#{limit}"
  end
  candidates.each do |candidate|
    puts "de-DE keyword candidate #{candidate.fetch("id")}: #{candidate.fetch("characters")}/100 (#{candidate.fetch("status")})"
  end
  puts "en-US control SHA-256: #{Digest::SHA256.file(control_path).hexdigest}"
  puts "target locales: de-DE"
  puts "protected locales: en-US"
  puts "keyword status: FINAL_ASTRO_VALIDATED_REQUIRES_EXPLICIT_USER_APPROVAL"
  puts "ASC mutation: none"
  puts "RESULT: PASS"
else
  warn errors.map { |error| "ERROR: #{error}" }.join("\n")
  warn "RESULT: FAIL"
  exit 1
end
