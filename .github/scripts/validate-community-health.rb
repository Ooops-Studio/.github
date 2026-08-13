# frozen_string_literal: true

require "pathname"
require "uri"
require "yaml"

ROOT = Pathname.new(__dir__).join("../..").expand_path
ERRORS = []

def fail_check(message)
  ERRORS << message
end

def load_yaml(relative_path)
  path = ROOT.join(relative_path)
  YAML.safe_load(path.read, permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::Exception => error
  fail_check("#{relative_path}: invalid YAML (#{error.message.lines.first.strip})")
  nil
end

required_files = %w[
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/config.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/pull_request_template.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
  LICENSE
  README.md
  SECURITY.md
  SUPPORT.md
  profile/README.md
]

required_files.each do |relative_path|
  path = ROOT.join(relative_path)
  fail_check("missing or empty required file: #{relative_path}") unless path.file? && path.size.positive?
end

%w[ISSUE_TEMPLATE PULL_REQUEST_TEMPLATE].each do |legacy_directory|
  fail_check("legacy template directory is forbidden: #{legacy_directory}") if ROOT.join(legacy_directory).exist?
end

Dir.glob(ROOT.join("**/* 2.md")).each do |path|
  fail_check("Finder conflict copy is forbidden: #{Pathname.new(path).relative_path_from(ROOT)}")
end

expected_forms = {
  ".github/ISSUE_TEMPLATE/bug_report.yml" => "bug",
  ".github/ISSUE_TEMPLATE/feature_request.yml" => "enhancement"
}

expected_forms.each do |relative_path, expected_label|
  form = load_yaml(relative_path)
  next unless form.is_a?(Hash)

  %w[name description body].each do |key|
    fail_check("#{relative_path}: missing #{key}") unless form.key?(key)
  end

  fail_check("#{relative_path}: title must be a string") unless form["title"].is_a?(String)
  fail_check("#{relative_path}: must assign templated issues to italiour") unless form["assignees"] == ["italiour"]
  fail_check("#{relative_path}: expected #{expected_label} label") unless Array(form["labels"]).include?(expected_label)

  body = form["body"]
  unless body.is_a?(Array) && !body.empty?
    fail_check("#{relative_path}: body must be a non-empty array")
    next
  end

  ids = body.map { |entry| entry.is_a?(Hash) ? entry["id"] : nil }.compact
  fail_check("#{relative_path}: body IDs must be unique") unless ids.uniq.length == ids.length
  fail_check("#{relative_path}: body ID is unsafe") unless ids.all? { |id| id.is_a?(String) && id.match?(/\A[a-zA-Z0-9_-]+\z/) }

  allowed_types = %w[checkboxes dropdown input markdown textarea upload]
  body.each_with_index do |entry, index|
    unless entry.is_a?(Hash) && allowed_types.include?(entry["type"])
      fail_check("#{relative_path}: invalid body entry at index #{index}")
    end
  end
end

config_path = ".github/ISSUE_TEMPLATE/config.yml"
config = load_yaml(config_path)
if config.is_a?(Hash)
  fail_check("#{config_path}: blank issues must remain disabled") unless config["blank_issues_enabled"] == false
  links = config["contact_links"]
  unless links.is_a?(Array) && !links.empty?
    fail_check("#{config_path}: contact_links must be a non-empty array")
  else
    links.each_with_index do |link, index|
      unless link.is_a?(Hash) && %w[name url about].all? { |key| link[key].is_a?(String) && !link[key].empty? }
        fail_check("#{config_path}: invalid contact link at index #{index}")
        next
      end

      uri = URI.parse(link["url"])
      fail_check("#{config_path}: unsupported contact URL scheme at index #{index}") unless %w[https mailto].include?(uri.scheme)
    rescue URI::InvalidURIError
      fail_check("#{config_path}: malformed contact URL at index #{index}")
    end
  end
end

pull_request_template = ROOT.join(".github/pull_request_template.md").read
%w[Summary Context Validation Impact].each do |heading|
  fail_check("pull request template is missing heading: #{heading}") unless pull_request_template.include?("## #{heading}")
end

Dir.glob(ROOT.join(".github/workflows/*.{yml,yaml}")).sort.each do |workflow_path|
  File.readlines(workflow_path).each_with_index do |line, index|
    match = line.match(/\buses:\s*["']?([^\s"']+)/)
    next unless match

    action = match[1]
    next if action.start_with?("./")

    reference = action.split("@").last
    unless reference&.match?(/\A[0-9a-f]{40}\z/)
      relative_path = Pathname.new(workflow_path).relative_path_from(ROOT)
      fail_check("#{relative_path}:#{index + 1}: external action must use a full commit SHA")
    end
  end
end

profile = ROOT.join("profile/README.md").read
required_repositories = %w[
  ooops-accessibility
  ooops-analytics
  ooops-astro-template
  ooops-cms-packages
  ooops-media-press
  ooops-packages-template
  ooops-system
  ooops-ui
]

required_repositories.each do |repository|
  fail_check("organization profile is missing #{repository}") unless profile.include?("https://github.com/ooops-studio/#{repository}")
end

fail_check("organization profile still contains the retired Stage CMS name") if profile.include?("Stage CMS")
fail_check("license owner/year is stale") unless ROOT.join("LICENSE").read.include?("Copyright (c) 2026 Ooops Design Studio")

if ERRORS.any?
  warn ERRORS.map { |error| "ERROR: #{error}" }.join("\n")
  exit 1
end

puts "Community health validation passed."
