#!/usr/bin/env ruby
# Deterministic, offline validator for issue #232's en-GB storefront package.

require "json"
require_relative "storefront_package"

root = File.expand_path("..", __dir__)
metadata = JSON.parse(File.read(File.join(root, "metadata", "en-GB-storefront.json")))
overlays = JSON.parse(File.read(File.join(root, "screenshots", "en-GB-overlays.json")))
result = StorefrontPackage.validate(root: root, metadata: metadata, overlays: overlays)
errors = result.errors.dup

committed_preview = File.read(File.join(root, "metadata", "additive-diff.md"))
errors << "committed dry-run preview is stale" unless committed_preview == result.preview

draft = metadata.fetch("drafts").fetch(0)
fields = draft.fetch("appInfo").merge(draft.fetch("versionLocalization"))
StorefrontPackage::FIELD_LIMITS.each do |field, limit|
  puts "en-GB #{field}: #{fields.fetch(field).length}/#{limit}"
end

frames = overlays.fetch("locales").fetch(0).fetch("overlays")
puts "en-GB screenshot overlays: #{frames.length}/5"
puts "en-US control SHA-256: #{result.control_sha256}"
puts "additive locales: #{result.added_locales.join(', ')}"

if errors.empty?
  puts "RESULT: PASS"
  exit 0
end

warn errors.join("\n")
warn "RESULT: FAIL (#{errors.length} issue#{errors.length == 1 ? '' : 's'})"
exit 1
