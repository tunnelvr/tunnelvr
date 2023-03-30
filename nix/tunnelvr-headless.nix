{ tunnelvr-godot-headless, tunnelvr_pck, writeScriptBin }:
writeScriptBin "tunnelvr-headless" ''
  ${tunnelvr-godot-headless}/bin/godot-headless --main-pack ${tunnelvr_pck}
''
