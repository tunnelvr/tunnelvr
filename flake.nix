{
  description = "TunnelVR for Nix automation purposes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs: {
    packages.x86_64-linux = let pkgs = import inputs.nixpkgs { system = "x86_64-linux"; }; in {
      tunnelvr = pkgs.callPackage ./tunnelvr.nix {};
    };
  };
}
  
