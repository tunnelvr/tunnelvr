{
  description = "TunnelVR for Nix automation purposes";


  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    godot = {
      url = "github:godotengine/godot/3.3";
      flake = false;
    };
    tunnelvr = {
      url = "github:goatchurchprime/tunnelvr/master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, godot, tunnelvr }: {

#    packages.x86_64-linux = let pkgs = import nixpkgs { system = "x86_64-linux"; }; in {
#      tunnelvr = pkgs.callPackage ./nix/runcommand-tunnelvr.nix {};
#    };

    nixosModules.tunnelvr =
      { pkgs, ... }:
      {
        imports = [ ./nix/tunnelvr-service.nix ];
        nixpkgs.overlays = [ self.overlay ];
      };

    overlay = final: prev:
    let 
      inherit (final) stdenv lib fetchFromGitHub godot-headless godot-export-templates fetchurl runCommandNoCC unzip;
    in
    {
      my-godot-headless = godot-headless.overrideAttrs (oldAttrs: rec {
        version = godot.rev;
        src = godot;
        patches = [];
      });

      tunnelvr = 
      runCommandNoCC "tunnelvr" {

        buildInputs = [ final.my-godot-headless godot-export-templates ];

        src = tunnelvr;

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

