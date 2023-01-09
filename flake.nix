{
  description = "TunnelVR for Nix automation purposes";

  nixConfig = {
    extra-substituters = ["https://tunnelvr.cachix.org"];
    extra-trusted-public-keys = ["tunnelvr.cachix.org-1:IZUIF+ytsd6o+5F0wi45s83mHI+aQaFSoHJ3zHrc2G0="];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    godot-source = {
      url = "github:godotengine/godot/3.5.1-stable";
      flake = false;
    };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, godot-source, flake-compat, flake-compat-ci }:
    let
      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 self.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlay ];
          config.android_sdk.accept_license = true;
        });

    in {

      ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
        flake = self;
        systems = [ "x86_64-linux" ];
      };

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor."${system}";
        in rec {
          tunnelvr_head_withPrograms = pkgs.tunnelvr_head_withPrograms;
          tunnelvr_headless_withPrograms = pkgs.tunnelvr_headless_withPrograms;
          tunnelvr_head = pkgs.tunnelvr_head;
          tunnelvr_headless = pkgs.tunnelvr_headless;
          tunnelvr_pck = pkgs.tunnelvr_pck;
        });

      nixosModules.tunnelvr = { pkgs, ... }: {
        imports = [ ./nix/tunnelvr-service.nix ];
        nixpkgs.overlays = [ self.overlay ];
      };

      devShell = forAllSystems (system:
        let pkgs = nixpkgsFor."${system}";
        in pkgs.mkShell {
          buildInputs = with pkgs; [ my-godot-wrapped jre_headless ];
        });

      overlay = final: prev:
        let
          inherit (final)
            stdenv lib fetchFromGitHub godot godot-headless
            godot-export-templates fetchurl runCommandNoCC unzip symlinkJoin;
        in {
          my-godot-headless = godot-headless.overrideAttrs (oldAttrs: rec {
            version = godot-source.rev;
            src = godot-source;
          });
          my-godot-wrapped = symlinkJoin {
            name = "my-godot-with-android-sdk";
            nativeBuildInputs = [ final.makeWrapper ];
            paths = [ final.my-godot ];
            postBuild =
              let
                # Godot's source code has `version.py` in it, which means we
                # can parse it using regex in order to construct the link to
                # download the export templates from.
                version = rec {
                  # Fully constructed string, example: "3.5".
                  string = "${major + "." + minor + (final.lib.optionalString (patch != "") "." + patch)}";
                  file = "${godot-source}/version.py";
                  major = toString (builtins.match ".+major = ([0-9]+).+" (builtins.readFile file));
                  minor = toString (builtins.match ".+minor = ([0-9]+).+" (builtins.readFile file));
                  patch = toString (builtins.match ".+patch = ([1-9]+).+" (builtins.readFile file));
                  # stable, rc, dev, etc.
                  status = toString (builtins.match ".+status = \"([A-z]+)\".+" (builtins.readFile file));
                };
                debugKey = final.runCommand "debugKey" {} ''
                  ${final.jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                  mv debug.keystore $out
                '';
                export-templates = final.fetchurl {
                  url = "https://downloads.tuxfamily.org/godotengine/${version.string}/Godot_v${version.string}-${version.status}_export_templates.tpz";
                  sha256 = "sha256-gqTv9Z/AUFxInh5HPLrESDOwQMGk38QXI1xPYjBQqEo=";
                  recursiveHash = true;
                  # postFetch is necessary because the downloaded file has a
                  # .tpz extension, meaning `fetchzip` cannot otherwise extract
                  # it properly. Additionally, the game engine expects the
                  # template path to be in a folder by the name of the current
                  # version + status, like '3.4.2-stable/templates' for example,
                  # so we accomplish that here.
                  downloadToTemp = true;
                  postFetch = ''
                    ${final.unzip}/bin/unzip $downloadedFile -d ./
                    mkdir -p $out/templates/${version.string}.${version.status}
                    mv ./templates/* $out/templates/${version.string}.${version.status}
                  '';
                };
              in
              ''
                wrapProgram $out/bin/godot \
                  --set tunnelvr_ANDROID_SDK "${final.androidenv.androidPkgs_9_0.androidsdk}/libexec/android-sdk"\
                  --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
                  --set tunnelvr_DEBUG_KEY "${debugKey}"
              '';
          };
          my-godot = godot.overrideAttrs (oldAttrs: rec {
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
          });

          tunnelvr_pck = runCommandNoCC "tunnelvr" {

            buildInputs = [ final.my-godot-headless godot-export-templates ];

            src = self;

          } ''
            mkdir -p "$TMP/.config"
            mkdir -p "$TMP/.local/share/godot/templates"
            mkdir -p "$TMP/.config/godot/projects/"
            export HOME=$TMP
            export XDG_CONFIG_HOME="$TMP/.config"
            export XDG_DATA_HOME="$TMP/.local/share"
            ln -s ${godot-export-templates} "$TMP/.local/share"

            cp -r $src $TMP/src
            chmod -R u+w -- "$TMP/src"
            godot-headless --path "$TMP/src" --export-pack "Linux/X11" tunnelvr.pck
            mv $TMP/src/tunnelvr.pck $out
          '';
          tunnelvr_head = prev.writeScriptBin "tunnelvr_head" ''
            ${final.my-godot}/bin/godot --main-pack ${final.tunnelvr_pck}
          '';
          tunnelvr_head_withPrograms = prev.symlinkJoin {
            name = "tunnelvr";
            paths = [ final.tunnelvr_head ];
            buildInputs = [ prev.makeWrapper ];
            postBuild = ''
              ls -lah $out/bin
              wrapProgram "$out/bin/tunnelvr_head" --prefix PATH : ${
                with prev;
                lib.makeBinPath [ (pkgs.python39.withPackages (ps: [ pkgs.python39Packages.pyproj ])) survex caddy python39Packages.pyproj ]
              }
            '';
          };
          tunnelvr_headless = prev.writeScriptBin "tunnelvr_headless" ''
            ${final.my-godot-headless}/bin/godot-headless --main-pack ${final.tunnelvr_pck}
          '';
          tunnelvr_headless_withPrograms = prev.symlinkJoin {
            name = "tunnelvr";
            paths = [ final.tunnelvr_headless ];
            buildInputs = [ prev.makeWrapper ];
            postBuild = ''
              ls -lah $out/bin
              wrapProgram "$out/bin/tunnelvr_headless" --prefix PATH : ${
                with prev;
                lib.makeBinPath [ (pkgs.python39.withPackages (ps: [ pkgs.python39Packages.pyproj ])) survex caddy ]
              }
            '';
          };
        };
    };
}

