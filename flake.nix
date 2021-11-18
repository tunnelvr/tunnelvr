{
  description = "TunnelVR for Nix automation purposes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    godot-source = {
      url = "github:godotengine/godot/3.4-stable";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, godot-source }:
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
          overlays = [ self.overlay ];
        });

    in {

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
          buildInputs = [ pkgs.my-godot ];
        });

      overlay = final: prev:
        let
          inherit (final)
            stdenv lib fetchFromGitHub godot godot-headless
            godot-export-templates fetchurl runCommandNoCC unzip;
        in {
          my-godot-headless = godot-headless.overrideAttrs (oldAttrs: rec {
            version = godot-source.rev;
            src = godot-source;
          });
          my-godot = godot.overrideAttrs (oldAttrs: rec {
            version = godot-source.rev;
            src = godot-source;
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

