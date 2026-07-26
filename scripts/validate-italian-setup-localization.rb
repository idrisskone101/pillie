#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

root = File.expand_path("..", __dir__)
catalogs = {
  "main UI" => "Pillie/Pillie/Localizable.xcstrings",
  "notifications" => "Pillie/Pillie/Notifications.xcstrings",
  "commerce boundary" => "Pillie/Pillie/Commerce.xcstrings",
  "shield configuration" => "Pillie/PillieShieldConfiguration/Shield.xcstrings",
  "device activity monitor" => "Pillie/PillieDeviceActivityMonitor/Shield.xcstrings"
}
placeholder = /%(?:\d+\$)?(?:@|lld|ld|d|f)/
prohibited = [
  /never miss/i,
  /non dimenticare mai/i,
  /always protected/i,
  /sempre protetta/i,
  /prevents pregnancy/i,
  /evita la gravidanza/i,
  /guaranteed/i,
  /garantito/i
]
errors = []

catalogs.each do |label, relative_path|
  path = File.join(root, relative_path)
  data = JSON.parse(File.read(path))
  strings = data.fetch("strings")
  errors << "#{label}: empty catalog" if strings.empty?

  strings.each do |key, entry|
    localizations = entry.fetch("localizations", {})
    english = localizations.dig("en", "stringUnit", "value")
    italian = localizations.dig("it", "stringUnit", "value")
    errors << "#{label}: #{key} missing English" if english.nil? || english.empty?
    errors << "#{label}: #{key} missing Italian" if italian.nil? || italian.empty?
    next unless english && italian

    if english.scan(placeholder).sort != italian.scan(placeholder).sort
      errors << "#{label}: #{key} placeholder mismatch"
    end
    prohibited.each do |pattern|
      errors << "#{label}: #{key} contains prohibited claim #{pattern.inspect}" if italian.match?(pattern)
    end
  end
end

shield_keys = %w[
  shield.title shield.subtitle shield.secondary shield.primary_action shield.blocking_reason
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

abort(errors.join("\n")) unless errors.empty?
puts "Italian setup localization validation passed (#{catalogs.length} target catalogs)."
