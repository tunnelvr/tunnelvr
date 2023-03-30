{ lib, symlinkJoin, makeWrapper, tunnelvr, python39, survex, caddy }:
symlinkJoin {
  name = "tunnelvr";
  paths = [ tunnelvr ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    ls -lah $out/bin
    wrapProgram "$out/bin/tunnelvr" --prefix PATH : ${
      lib.makeBinPath [ (python39.withPackages (ps: [ ps.pyproj ])) survex caddy ]
    }
  '';
}
