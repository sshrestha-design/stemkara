require 'xcodeproj'

project_path = '/Users/sagarshrestha/.gemini/antigravity/scratch/Musify/macos/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = 'MusifyWidget'
existing_target = project.targets.find { |t| t.name == target_name }

if existing_target
  puts "Target #{target_name} already exists"
else
  target = project.new_target(:app_extension, target_name, :osx, '14.0')
  target.product_type = 'com.apple.product-type.app-extension'
  target.product_name = 'MusifyWidget'

  group = project.main_group.find_subpath('MusifyWidget', true)
  source_file = group.new_file('MusifyWidget/MusifyWidget.swift')

  target.source_build_phase.add_file_reference(source_file)

  # Frameworks
  ['WidgetKit.framework', 'SwiftUI.framework', 'AppIntents.framework'].each do |fw|
    file_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{fw}", :sdk_root)
    target.frameworks_build_phase.add_file_reference(file_ref)
  end

  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = 'MusifyWidget'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gokadzev.musify.MusifyWidget'
    config.build_settings['INFOPLIST_FILE'] = 'MusifyWidget/Info.plist'
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'MusifyWidget/MusifyWidget.entitlements'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  end

  runner_target = project.targets.find { |t| t.name == 'Runner' }
  if runner_target
    runner_target.add_dependency(target)

    embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' || p.dst_subfolder_spec == 13 }
    unless embed_phase
      embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
      embed_phase.dst_subfolder_spec = "13" # 13 is PlugIns folder
    end

    build_file = embed_phase.add_file_reference(target.product_reference)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end

  project.save
  puts "Successfully added #{target_name} target to #{project_path}"
end
