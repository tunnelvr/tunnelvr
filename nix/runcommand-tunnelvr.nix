{ stdenv, lib, fetchFromGitHub, godot-headless, godot-export-templates, fetchurl, runCommandNoCC, unzip }:

let
  my-godot-headless = godot-headless.overrideAttrs (oldAttrs: rec {
    src = fetchFromGitHub {
      owner  = "godotengine";
      repo   = "godot";
      rev    = "3.3-stable";
      sha256 = "sha256:0lclrx0y7w1dah40053sjlppb6c5p32icq7x5pvdfgyd3i63mnbb";
    };
    patches = [];
  });
in
runCommandNoCC "tunnelvr" { 

  buildInputs = [ godot-headless godot-export-templates ]; 

  src = fetchGit {
    url = "https://github.com/goatchurchprime/tunnelvr.git";
    rev = "97b3118b56a36f67e385d5951d2ec79bce948bb9";
    ref = "refs/heads/nix";
  };

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
''

