#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

ROOT = File.expand_path("..", __dir__)
SKILLS_ROOT = File.join(ROOT, "skills")

def fail_with(message)
  warn "ERROR: #{message}"
  exit 1
end

def parse_frontmatter(path)
  text = File.read(path)
  match = text.match(/\A---\n(.*?)\n---\n/m)
  fail_with("#{path}: missing YAML frontmatter") unless match

  data = YAML.safe_load(match[1])
  fail_with("#{path}: frontmatter must be a YAML object") unless data.is_a?(Hash)

  [data, text]
end

skill_dirs = Dir.glob(File.join(SKILLS_ROOT, "*", "*")).select { |path| File.directory?(path) }.sort
fail_with("no skills found under #{SKILLS_ROOT}") if skill_dirs.empty?

skill_dirs.each do |dir|
  category = File.basename(File.dirname(dir))
  skill_name = File.basename(dir)
  skill_md = File.join(dir, "SKILL.md")
  openai_yaml = File.join(dir, "agents", "openai.yaml")

  fail_with("#{dir}: invalid category name") unless category.match?(/\A[a-z0-9-]+\z/)
  fail_with("#{dir}: invalid skill directory name") unless skill_name.match?(/\A[a-z0-9-]+\z/)
  fail_with("#{dir}: missing SKILL.md") unless File.file?(skill_md)
  fail_with("#{dir}: missing agents/openai.yaml") unless File.file?(openai_yaml)

  frontmatter, skill_text = parse_frontmatter(skill_md)
  expected_keys = %w[description name]
  actual_keys = frontmatter.keys.sort
  fail_with("#{skill_md}: frontmatter keys must be #{expected_keys.join(', ')}") unless actual_keys == expected_keys
  fail_with("#{skill_md}: frontmatter name must match folder name") unless frontmatter["name"] == skill_name
  fail_with("#{skill_md}: description must be a non-empty string") unless frontmatter["description"].is_a?(String) && !frontmatter["description"].strip.empty?
  fail_with("#{skill_md}: contains unresolved TODO markers") if skill_text.include?("[TODO:")

  openai = YAML.safe_load(File.read(openai_yaml))
  fail_with("#{openai_yaml}: must be a YAML object") unless openai.is_a?(Hash)

  interface = openai["interface"]
  fail_with("#{openai_yaml}: missing interface section") unless interface.is_a?(Hash)

  %w[display_name short_description default_prompt].each do |key|
    value = interface[key]
    fail_with("#{openai_yaml}: missing interface.#{key}") unless value.is_a?(String) && !value.strip.empty?
  end

  unless interface["default_prompt"].include?("$#{skill_name}")
    fail_with("#{openai_yaml}: interface.default_prompt must mention $#{skill_name}")
  end
end

puts "Validated #{skill_dirs.length} skill(s)"
