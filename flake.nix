{
  description = "TunnelVR for Nix automation purposes";

  nixConfig = {
    extra-substituters = ["https://tunnelvr.cachix.org"];
    extra-trusted-public-keys = ["tunnelvr.cachix.org-1:IZUIF+ytsd6o+5F0wi45s83mHI+aQaFSoHJ3zHrc2G0="];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    godot-source = {
      url = "github:godotengine/godot/3.5.3-stable";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { self, nixpkgs, godot-source, flake-parts }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      flake = {
        herculesCI.ciSystems = [ "x86_64-linux" ];
        nixosModules.tunnelvr = { config, lib, pkgs, ... }: {
          imports = [ (import ./nix/tunnelvr-service.nix { inherit self config lib pkgs; }) ];
        };
      };
      perSystem = { config, system, pkgs, final, ... }: {
        _module.args.pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };
        overlayAttrs = config.packages;
        packages = {
          tunnelvr = final.callPackage ./nix/tunnelvr.nix { };
          tunnelvr_pck = final.callPackage ./nix/tunnelvr_pck.nix { src = self; };
          tunnelvr-headless = final.callPackage ./nix/tunnelvr-headless.nix { };
          tunnelvr-godot-headless = final.callPackage ./nix/tunnelvr-godot-headless.nix { inherit godot-source; };
          tunnelvr-godot = final.callPackage ./nix/tunnelvr-godot { inherit godot-source; };
          tunnelvr-godot-unwrapped = final.callPackage ./nix/tunnelvr-godot/unwrapped.nix { inherit godot-source; };
          tunnelvr_withPrograms = final.callPackage ./nix/tunnelvr-with-programs.nix {};
          tunnelvr-headless_withPrograms = final.callPackage ./nix/tunnelvr-headless-with-programs.nix {};
          Dpotreeconverter = final.callPackage ./nix/potreeconverter { };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            final.tunnelvr-godot
            jre_headless
            caddy survex final.Dpotreeconverter
            python310Packages.pyproj
            python310Packages.laspy
            python310Packages.ipfshttpclient
          ];
        };
      };
    };
}

