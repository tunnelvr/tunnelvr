{ godot_4, godot-source, fetchpatch }:
godot_4.overrideAttrs (old: {
  version = godot-source.rev;
  src = godot-source;
  patches = (old.patches or []) ++ [
    # https://github.com/godotengine/godot/pull/79143
    (fetchpatch {
      url = "https://github.com/clayjohn/godot/commit/df021b5063897eb4fe4a716aefc7096209ed29c6.patch";
      hash = "sha256-KDmYWNivbsO7Rg3reMRUJVac025Incx7h5rh7KpVsnE=";
    })
  ];
  preBuild =
    ''
      substituteInPlace platform/android/export/export_plugin.cpp \
          --replace 'String sdk_path = EDITOR_GET("export/android/android_sdk_path")' 'String sdk_path = std::getenv("tunnelvr_ANDROID_SDK")'

      substituteInPlace platform/android/export/export_plugin.cpp \
          --replace 'EDITOR_GET("export/android/debug_keystore")' 'std::getenv("tunnelvr_DEBUG_KEY")'

      substituteInPlace editor/editor_paths.cpp \
          --replace 'return get_data_dir().path_join(export_templates_folder)' 'return std::getenv("tunnelvr_EXPORT_TEMPLATES")'
    '';
})
