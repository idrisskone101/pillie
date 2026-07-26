#!/usr/bin/env ruby

require "json"

root = File.expand_path("..", __dir__)
catalog_specs = {
  File.join(root, "Pillie/Pillie/Localizable.xcstrings") =>
    %w[global. today. history. settings. support. error. empty. accessibility. legal.],
  File.join(root, "Pillie/Pillie/Commerce.xcstrings") =>
    %w[paywall. trial.],
}
errors = []
italian_values = []

catalog_specs.each do |path, prefixes|
  strings = JSON.parse(File.read(path)).fetch("strings")
  covered = strings.select { |key, _| prefixes.any? { |prefix| key.start_with?(prefix) } }
  covered.each do |key, entry|
    localizations = entry.fetch("localizations", {})
    english = localizations.dig("en", "stringUnit", "value")
    italian = localizations.dig("it", "stringUnit", "value")
    errors << "#{key}: missing English control" if english.nil? || english.empty?
    errors << "#{key}: missing Italian localization" if italian.nil? || italian.empty?
    next unless english && italian

    placeholder = /%(?:\d+\$)?(?:lld|@)/
    errors << "#{key}: placeholder mismatch" unless english.scan(placeholder) == italian.scan(placeholder)
    italian_values << [key, italian]
  end
end

prohibited = [
  "non dimenticare mai",
  "garantito",
  "sempre protetta",
  "evita la gravidanza",
  "assicura l'aderenza",
  "hai fallito",
]
italian_values.each do |key, value|
  normalized = value.downcase
  prohibited.each do |phrase|
    errors << "#{key}: prohibited claim '#{phrase}'" if normalized.include?(phrase)
  end
end

covered_sources = %w[
  Pillie/Pillie/Views/Home
  Pillie/Pillie/Views/Onboarding/PremiumPaywallView.swift
  Pillie/Pillie/Views/Onboarding/TrialGrantedMomentView.swift
  Pillie/Pillie/Views/Settings
  Pillie/Pillie/Views/Calendar
  Pillie/Pillie/Services/CommercePresentation.swift
  Pillie/Pillie/Services/TrialEndPaywallPresentation.swift
].flat_map do |relative|
  path = File.join(root, relative)
  File.directory?(path) ? Dir[File.join(path, "**/*.swift")] : [path]
end

forbidden_source_patterns = {
  /"\$(?:29\.99|4\.99)/ => "hard-coded subscription amount",
  /"\/(?:mo|yr|month|year)"/ => "hard-coded English subscription suffix",
  /Locale\(identifier:\s*"en_US"\)/ => "hard-coded en_US locale",
  /ForEach\(\["Reminders stay free forever"/ => "hard-coded English paywall reassurance",
}
covered_sources.each do |path|
  source = File.read(path)
  forbidden_source_patterns.each do |pattern, label|
    errors << "#{path.delete_prefix("#{root}/")}: #{label}" if source.match?(pattern)
  end
end

if errors.empty?
  puts "Italian daily-use localization validation passed (#{italian_values.length} catalog rows)."
  exit 0
end

warn errors.join("\n")
exit 1
