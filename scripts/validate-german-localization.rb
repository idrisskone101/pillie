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
    errors << "#{label}: #{key} missing English control" if english.nil? || english.empty?
    errors << "#{label}: #{key} missing German localization" if german.nil? || german.empty?
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

abort(errors.join("\n")) unless errors.empty?

puts "German localization validation passed (#{row_count} rows across #{catalogs.length} target catalogs)."
