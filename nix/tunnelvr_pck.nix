{ runCommand, src, tunnelvr-godot-headless, godot-export-templates }:
runCommand "tunnelvr_pck" {
  buildInputs = [ tunnelvr-godot-headless godot-export-templates ];
  inherit src;
}
''
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
