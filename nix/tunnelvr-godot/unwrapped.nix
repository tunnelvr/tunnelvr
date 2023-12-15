{ godot3, godot-source }:
godot3.overrideAttrs (_: {
  version = godot-source.rev;
  src = godot-source;
  preBuild =
    ''
      substituteInPlace platform/android/export/export_plugin.cpp \
        --replace 'String sdk_path = EditorSettings::get_singleton()->get("export/android/android_sdk_path")' 'String sdk_path = std::getenv("tunnelvr_ANDROID_SDK")'

      substituteInPlace platform/android/export/export_plugin.cpp \
        --replace 'EditorSettings::get_singleton()->get("export/android/debug_keystore")' 'std::getenv("tunnelvr_DEBUG_KEY")'

      substituteInPlace editor/editor_settings.cpp \
        --replace 'get_data_dir().plus_file("templates")' 'std::getenv("tunnelvr_EXPORT_TEMPLATES")'
    '';
})
