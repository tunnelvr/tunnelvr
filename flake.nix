{
  description = "TunnelVR for Nix automation purposes";


  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    survex.url = "github:matthewcroughan/nixpkgs/add-survex";
    godot-source = {
      url = "github:godotengine/godot/3.3.2-stable";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, godot-source, survex }:
    let
      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 self.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in
    {

#    packages.x86_64-linux = let pkgs = import nixpkgs { system = "x86_64-linux"; }; in {
#      tunnelvr = pkgs.callPackage ./nix/runcommand-tunnelvr.nix {};
#    };

    nixosModules.tunnelvr =
      { pkgs, ... }:
      {
        imports = [ ./nix/tunnelvr-service.nix ];
        nixpkgs.overlays = [ self.overlay ];
      };

    devShell = forAllSystems (system:
      let
        pkgs = nixpkgsFor."${system}";
      in
        pkgs.mkShell {
          buildInputs = [
            pkgs.my-godot
          ];

          shellHook = ''
            run-godot(){
              cd ../ && godot
            }
          '';
        }
    );

    overlay = final: prev:
    let 
      inherit (final) stdenv lib fetchFromGitHub godot godot-headless godot-export-templates fetchurl runCommandNoCC unzip;
    in
    {
      my-godot-headless = godot-headless.overrideAttrs (oldAttrs: rec {
        version = godot-source.rev;
        src = godot-source;
      });
      my-godot = godot.overrideAttrs (oldAttrs: rec {
        version = godot-source.rev;
        src = godot-source;
      });

      survex = survex.legacyPackages.x86_64-linux.survex;

      tunnelvr = 
        runCommandNoCC "tunnelvr" {

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
    };
  };
}

