#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

root = File.expand_path("..", __dir__)
catalogs = {
  "main UI" => "Pillie/Pillie/Localizable.xcstrings",
  "notifications" => "Pillie/Pillie/Notifications.xcstrings",
  "commerce" => "Pillie/Pillie/Commerce.xcstrings",
  "device activity monitor" => "Pillie/PillieDeviceActivityMonitor/Shield.xcstrings",
  "shield configuration" => "Pillie/PillieShieldConfiguration/Shield.xcstrings",
}
placeholder = /%(?:\d+\$)?(?:@|lld|ld|d|f)/
prohibited_claims = [
  /nie vergessen/i,
  /garantiert/i,
  /immer geschützt/i,
  /verhindert (?:eine |die )?schwangerschaft/i,
  /schützt vor (?:einer |der )?schwangerschaft/i,
  /du hast versagt/i,
  /deine schuld/i,
]
formal_address = /\b(?:Sie|Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Ihres)\b/
errors = []
row_count = 0

catalogs.each do |label, relative_path|
  path = File.join(root, relative_path)
  strings = JSON.parse(File.read(path)).fetch("strings")
  errors << "#{label}: empty catalog" if strings.empty?

  strings.each do |key, entry|
    row_count += 1
    localizations = entry.fetch("localizations", {})
    english = localizations.dig("en", "stringUnit", "value")
    german = localizations.dig("de", "stringUnit", "value")
    german_state = localizations.dig("de", "stringUnit", "state")
    errors << "#{label}: #{key} missing English control" if english.nil? || english.empty?
    errors << "#{label}: #{key} missing German localization" if german.nil? || german.empty?
    unless german_state == "translated"
      errors << "#{label}: #{key} German localization state is #{german_state.inspect}, expected \"translated\""
    end
    next unless english && german

    if english.scan(placeholder).sort != german.scan(placeholder).sort
      errors << "#{label}: #{key} placeholder mismatch"
    end
    prohibited_claims.each do |pattern|
      errors << "#{label}: #{key} contains prohibited claim #{pattern.inspect}" if german.match?(pattern)
    end
    if german.match?(formal_address)
      errors << "#{label}: #{key} uses formal address inside the app"
    end
  end
end

shield_keys = %w[
  shield.title
  shield.subtitle
  shield.secondary
  shield.primary_action
  shield.blocking_reason
]
%w[
  Pillie/PillieShieldConfiguration/Shield.xcstrings
  Pillie/PillieDeviceActivityMonitor/Shield.xcstrings
].each do |relative_path|
  strings = JSON.parse(File.read(File.join(root, relative_path))).fetch("strings")
  (shield_keys - strings.keys).each do |key|
    errors << "#{relative_path}: missing #{key}"
  end
end

notification_strings = JSON.parse(
  File.read(File.join(root, "Pillie/Pillie/Notifications.xcstrings"))
).fetch("strings")
unexpected_notification_keys = notification_strings.keys.reject do |key|
  key.start_with?("notification.")
end
unless unexpected_notification_keys.empty?
  errors << "notifications: unexpected target keys #{unexpected_notification_keys.join(", ")}"
end

commerce_strings = JSON.parse(
  File.read(File.join(root, "Pillie/Pillie/Commerce.xcstrings"))
).fetch("strings")
allowed_commerce_prefixes = %w[paywall. trial.]
allowed_commerce_keys = %w[
  onboarding.blocking_setup.plus_locked
  onboarding.demo.free_body
]
unexpected_commerce_keys = commerce_strings.keys.reject do |key|
  allowed_commerce_prefixes.any? { |prefix| key.start_with?(prefix) } ||
    allowed_commerce_keys.include?(key)
end
unless unexpected_commerce_keys.empty?
  errors << "commerce: unexpected target keys #{unexpected_commerce_keys.join(", ")}"
end

def parse_strings_file(path)
  File.read(path).scan(
    /^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$/
  ).to_h
end

info_plist_expectations = {
  "Pillie/Pillie/de.lproj/InfoPlist.strings" => {
    "NSMotionUsageDescription" =>
      "Pillie verwendet Bewegungssensoren, um Schütteln zu erkennen, wenn du eine Aktion bestätigst.",
    "NSUserTrackingUsageDescription" =>
      "Erlaube das Tracking, damit wir nachvollziehen können, über welche Kanäle du Pillie gefunden hast, und die App verbessern können. Wir verkaufen deine personenbezogenen Daten niemals.",
  },
  "Pillie/PillieDeviceActivityMonitor/de.lproj/InfoPlist.strings" => {
    "CFBundleDisplayName" => "Pillie",
  },
  "Pillie/PillieShieldAction/de.lproj/InfoPlist.strings" => {
    "CFBundleDisplayName" => "Pillie",
  },
  "Pillie/PillieShieldConfiguration/de.lproj/InfoPlist.strings" => {
    "CFBundleDisplayName" => "Pillie",
  },
}

info_plist_expectations.each do |relative_path, expected_values|
  path = File.join(root, relative_path)
  unless File.file?(path)
    errors << "#{relative_path}: missing German InfoPlist.strings resource"
    next
  end

  actual_values = parse_strings_file(path)
  expected_values.each do |key, expected_value|
    actual_value = actual_values[key]
    unless actual_value == expected_value
      errors << "#{relative_path}: #{key} is #{actual_value.inspect}, expected #{expected_value.inspect}"
    end
  end
end

project_path = File.join(root, "Pillie/Pillie.xcodeproj/project.pbxproj")
if File.file?(project_path)
  known_regions_block = File.read(project_path).match(/knownRegions = \((.*?)\);/m)
  if known_regions_block
    known_regions = known_regions_block[1].lines.map do |line|
      line.strip.delete_suffix(",").delete_prefix('"').delete_suffix('"')
    end
    errors << "Xcode project: German is missing from knownRegions" unless known_regions.include?("de")
  else
    errors << "Xcode project: missing knownRegions block"
  end
else
  errors << "Xcode project: missing project.pbxproj"
end

abort(errors.join("\n")) unless errors.empty?

puts "German localization validation passed (#{row_count} rows across #{catalogs.length} target catalogs)."
