#!/usr/bin/env ruby

require "optparse"

options = {
  input: File.expand_path("../../RELEASE_NOTES.md", __dir__)
}

OptionParser.new do |parser|
  parser.banner = "Usage: extract_release_notes.rb --tag vX.Y.Z --output PATH [--input PATH]"
  parser.on("--tag TAG", "Release tag") { |value| options[:tag] = value }
  parser.on("--input PATH", "Release notes source") { |value| options[:input] = value }
  parser.on("--output PATH", "Generated release notes") { |value| options[:output] = value }
end.parse!

abort("release notes: tag must match vX.Y.Z") unless options[:tag]&.match?(/^v\d+\.\d+\.\d+$/)
abort("release notes: --output is required") if options[:output].to_s.empty?
abort("release notes: source file is missing: #{options[:input]}") unless File.file?(options[:input])

lines = File.readlines(options[:input], encoding: "UTF-8")
heading = "## #{options[:tag]}"
start_index = lines.index { |line| line.chomp == heading }
abort("release notes: missing exact heading #{heading} in #{options[:input]}") unless start_index

section = lines[(start_index + 1)..]&.take_while { |line| !line.match?(/^##\s+/) }&.join.to_s.strip
abort("release notes: #{heading} has no user-facing content") if section.empty?

File.write(options[:output], <<~MARKDOWN)
  # MemoryFlow Island #{options[:tag]}

  Unsigned open-source release. On first launch, use right-click Open or approve the app in Privacy and Security.

  ## Changes

  #{section}
MARKDOWN
