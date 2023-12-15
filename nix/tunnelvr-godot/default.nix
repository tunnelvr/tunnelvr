{ makeWrapper, symlinkJoin, lib, unzip, godot-source, tunnelvr-godot-unwrapped, runCommand, fetchurl, androidenv, jre_minimal }:
symlinkJoin {
  name = "tunnelvr-godot-with-android-sdk";
  nativeBuildInputs = [ makeWrapper ];
  paths = [ tunnelvr-godot-unwrapped ];
  postBuild =
    let
      # Godot's source code has `version.py` in it, which means we
      # can parse it using regex in order to construct the link to
      # download the export templates from.
      version = rec {
        # Fully constructed string, example: "3.5".
        string = "${major + "." + minor + (lib.optionalString (patch != "") "." + patch)}";
        file = "${godot-source}/version.py";
        major = toString (builtins.match ".+major = ([0-9]+).+" (builtins.readFile file));
        minor = toString (builtins.match ".+minor = ([0-9]+).+" (builtins.readFile file));
        patch = toString (builtins.match ".+patch = ([1-9]+).+" (builtins.readFile file));
        # stable, rc, dev, etc.
        status = toString (builtins.match ".+status = \"([A-z]+)\".+" (builtins.readFile file));
      };
      debugKey = runCommand "debugKey" {} ''
        ${jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
        mv debug.keystore $out
      '';
      export-templates = fetchurl {
        url = "https://downloads.tuxfamily.org/godotengine/${version.string}/Godot_v${version.string}-${version.status}_export_templates.tpz";
        sha256 = "sha256-fufpfAGoUzcCcdGoeVIpd7sceC5p6cZLSdQ9p0SOUDg=";
        recursiveHash = true;
        # postFetch is necessary because the downloaded file has a
        # .tpz extension, meaning `fetchzip` cannot otherwise extract
        # it properly. Additionally, the game engine expects the
        # template path to be in a folder by the name of the current
        # version + status, like '3.4.2-stable/templates' for example,
        # so we accomplish that here.
        downloadToTemp = true;
        postFetch = ''
          ${unzip}/bin/unzip $downloadedFile -d ./
          mkdir -p $out/templates/${version.string}.${version.status}
          mv ./templates/* $out/templates/${version.string}.${version.status}
        '';
      };
    in
    ''
      wrapProgram $out/bin/godot3 \
        --set tunnelvr_ANDROID_SDK "${androidenv.androidPkgs_9_0.androidsdk}/libexec/android-sdk"\
        --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
        --set tunnelvr_DEBUG_KEY "${debugKey}"
    '';
}
