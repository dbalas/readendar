# Adds ShareExtension + wires new Runner Swift sources into Runner.xcodeproj.
# Idempotent: skips recreate when ShareExtension already exists.
require 'xcodeproj'

proj_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(proj_path)

SHARE_NAME = 'ShareExtension'
SHARE_BUNDLE = 'com.readendar.readendar.ShareExtension'
RUNNER_SWIFT = %w[ReadendarAppShortcuts.swift SpotlightBridge.swift]

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

# --- Runner: add new Swift sources if missing ---
runner_group = project.main_group.children.find { |c| c.display_name == 'Runner' } ||
               project.main_group['Runner']
raise 'Runner group not found' unless runner_group

RUNNER_SWIFT.each do |name|
  existing = runner.source_build_phase.files_references.find { |r| r.path&.end_with?(name) }
  next if existing

  ref = runner_group.new_reference(name)
  runner.add_file_references([ref])
  puts "Added Runner source #{name}"
end

embed = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed App Extensions' }
unless embed
  embed = runner.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end

share = project.targets.find { |t| t.name == SHARE_NAME }
if share.nil?
  share = project.new_target(:app_extension, SHARE_NAME, :ios, '15.5', nil, :swift)
  group = project.main_group.new_group(SHARE_NAME, SHARE_NAME)
  swift_ref = group.new_reference('ShareViewController.swift')
  group.new_reference('Info.plist')
  group.new_reference('ShareExtension.entitlements')
  share.add_file_references([swift_ref])
  puts "Created #{SHARE_NAME} target"
else
  puts "#{SHARE_NAME} target already present"
end

share.add_system_framework('Social')
share.add_system_framework('UniformTypeIdentifiers')

share.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = SHARE_BUNDLE
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SKIP_INSTALL'] = 'YES'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['ENABLE_DEBUG_DYLIB'] = 'NO'
  s['CODE_SIGNING_ALLOWED'] = 'YES'
  s['CODE_SIGNING_REQUIRED'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks'
  ]
end

unless runner.dependencies.any? { |d| d.target == share }
  runner.add_dependency(share)
  puts "Added Runner → #{SHARE_NAME} dependency"
end

already_embedded = embed.files.any? { |f| f.display_name&.include?('ShareExtension') }
unless already_embedded
  bf = embed.add_file_reference(share.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts "Embedded #{SHARE_NAME}.appex"
end

project.save
puts "ShareExtension target ready (#{SHARE_BUNDLE}); Runner sources wired."
