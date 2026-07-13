#!/usr/bin/env ruby

require "cgi"
require "json"
require "rexml/document"
require "time"

required = %w[
  APPCAST_PATH ARCHIVE_NAME ARCHIVE_URL ARCHIVE_LENGTH ARCHIVE_SIGNATURE
  BUILD_VERSION MARKETING_VERSION MINIMUM_MACOS PHASED_ROLLOUT_INTERVAL
  PUBLICATION_DATE RELEASE_NOTES_PATH RELEASE_PAGE_URL REPOSITORY
]

missing = required.select { |name| ENV[name].to_s.empty? }
abort("Missing appcast inputs: #{missing.join(', ')}") unless missing.empty?

document = REXML::Document.new
document << REXML::XMLDecl.new("1.0", "UTF-8")
rss = document.add_element(
  "rss",
  {
    "version" => "2.0",
    "xmlns:sparkle" => "http://www.andymatuschak.org/xml-namespaces/sparkle"
  }
)
channel = rss.add_element("channel")
channel.add_element("title").text = "MemoryFlow Island Updates"
channel.add_element("link").text = "https://github.com/#{ENV.fetch('REPOSITORY')}/releases/latest/download/appcast.xml"
channel.add_element("description").text = "Unsigned MemoryFlow Island releases verified with Sparkle EdDSA signatures."
channel.add_element("language").text = "en"

item = channel.add_element("item")
item.add_element("title").text = "MemoryFlow Island #{ENV.fetch('MARKETING_VERSION')}"
item.add_element("pubDate").text = ENV.fetch("PUBLICATION_DATE")
item.add_element("link").text = ENV.fetch("RELEASE_PAGE_URL")
item.add_element("sparkle:version").text = ENV.fetch("BUILD_VERSION")
item.add_element("sparkle:shortVersionString").text = ENV.fetch("MARKETING_VERSION")
item.add_element("sparkle:minimumSystemVersion").text = ENV.fetch("MINIMUM_MACOS")
item.add_element("sparkle:phasedRolloutInterval").text = ENV.fetch("PHASED_ROLLOUT_INTERVAL")
item.add_element("description").add(REXML::CData.new(File.read(ENV.fetch("RELEASE_NOTES_PATH"))))
item.add_element(
  "enclosure",
  {
    "url" => ENV.fetch("ARCHIVE_URL"),
    "length" => ENV.fetch("ARCHIVE_LENGTH"),
    "type" => "application/octet-stream",
    "sparkle:edSignature" => ENV.fetch("ARCHIVE_SIGNATURE")
  }
)

File.open(ENV.fetch("APPCAST_PATH"), "w") do |file|
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.width = 1_000_000
  formatter.write(document, file)
  file.write("\n")
end

metadata_path = ENV["METADATA_PATH"]
unless metadata_path.to_s.empty?
  metadata = {
    tag: "v#{ENV.fetch('MARKETING_VERSION')}",
    marketing_version: ENV.fetch("MARKETING_VERSION"),
    build_version: Integer(ENV.fetch("BUILD_VERSION"), 10),
    minimum_macos: ENV.fetch("MINIMUM_MACOS"),
    archive: ENV.fetch("ARCHIVE_NAME"),
    archive_length: Integer(ENV.fetch("ARCHIVE_LENGTH"), 10),
    archive_sha256: ENV.fetch("ARCHIVE_SHA256")
  }
  File.write(metadata_path, JSON.pretty_generate(metadata) + "\n")
end
