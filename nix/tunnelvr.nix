{ tunnelvr-godot, tunnelvr_pck, writeScriptBin }:
writeScriptBin "tunnelvr" ''
  ${tunnelvr-godot}/bin/godot --main-pack ${tunnelvr_pck}
''
