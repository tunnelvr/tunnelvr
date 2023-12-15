{ tunnelvr-godot-headless, tunnelvr_pck, writeScriptBin }:
writeScriptBin "tunnelvr-headless" ''
  ${tunnelvr-godot-headless}/bin/godot3-headless --main-pack ${tunnelvr_pck}
''
