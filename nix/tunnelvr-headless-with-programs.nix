{ symlinkJoin, makeWrapper, tunnelvr-headless, lib, python39, survex, caddy }:
symlinkJoin {
  name = "tunnelvr-with-programs";
  paths = [ tunnelvr-headless ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    ls -lah $out/bin
    wrapProgram "$out/bin/tunnelvr-headless" --prefix PATH : ${
      lib.makeBinPath [ (python39.withPackages (ps: [ ps.pyproj ])) survex caddy ]
    }
  '';
}
