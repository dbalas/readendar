# Adds the ReadendarWidget extension target to Runner.xcodeproj programmatically
# (equivalent to Xcode's File > New > Target > Widget Extension), wires its
# source/Info.plist/entitlements, sets build settings for a simulator build, and
# embeds the .appex into the Runner app. Idempotent: re-running removes a prior
# ReadendarWidget target first.
require 'xcodeproj'

proj_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(proj_path)

NAME = 'ReadendarWidget'
BUNDLE_ID = 'com.readendar.readendar.ReadendarWidget'

# --- idempotency: drop any existing target + group + embed phase ---
project.targets.select { |t| t.name == NAME }.each do |t|
  t.remove_from_project
end
if (g = project.main_group.children.find { |c| c.display_name == NAME })
  g.remove_from_project
end
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner
runner.build_phases.select { |p| p.respond_to?(:name) && p.name == 'Embed App Extensions' }.each do |p|
  p.remove_from_project
  runner.build_phases.delete(p)
end

# --- create the app-extension target ---
target = project.new_target(:app_extension, NAME, :ios, '17.0', nil, :swift)

# --- group + file references ---
group = project.main_group.new_group(NAME, NAME)
swift_ref = group.new_reference('ReadendarWidget.swift')
group.new_reference('Info.plist')
group.new_reference('ReadendarWidget.entitlements')
target.add_file_references([swift_ref]) # .swift → sources phase

# --- build settings (both configs) ---
target.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'ReadendarWidget/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'ReadendarWidget/ReadendarWidget.entitlements'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SKIP_INSTALL'] = 'YES'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  # Xcode 16+ debug-dylib layout crashes WidgetKit extensions so they vanish
  # from Add Widget (XPC_EXIT_REASON_FAULT). Keep off for all configs.
  s['ENABLE_DEBUG_DYLIB'] = 'NO'
  # Keep signing on so Simulated.xcent (App Group + application-identifier) is
  # generated; resign_widget_simulator_entitlements.sh stamps it into the appex.
  s['CODE_SIGNING_ALLOWED'] = 'YES'
  s['CODE_SIGNING_REQUIRED'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'NO'
end

# --- embed the .appex into Runner ---
runner.add_dependency(target)
embed = runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(target.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Simulator: stamp Simulated.xcent into the appex (see script header).
resign_name = 'Resign Widget Simulator Entitlements'
runner.build_phases.select { |p| p.respond_to?(:name) && p.name == resign_name }.each do |p|
  p.remove_from_project
  runner.build_phases.delete(p)
end
resign = runner.new_shell_script_build_phase(resign_name)
resign.shell_script = "/bin/sh \"${SRCROOT}/resign_widget_simulator_entitlements.sh\"\n"
resign.always_out_of_date = '1'
resign.input_paths = ['${TARGET_BUILD_DIR}/${WRAPPER_NAME}/PlugIns/ReadendarWidget.appex']

project.save
puts "Added target #{NAME} (#{BUNDLE_ID}); Runner now embeds it."
