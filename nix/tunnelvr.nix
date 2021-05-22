{ stdenv, lib, fetchFromGitHub, godot-headless, fetchurl, runCommandNoCC, unzip }:

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
stdenv.mkDerivation rec {

  pname = "tunnelvr-headless";
  version = "6bbd23bf9f719dc7cdfd9de08addb62adbd52a62";

  src = fetchGit {
    url = "https://github.com/goatchurchprime/tunnelvr.git";
    rev = "c91524c8820ce47b1e0948f6c037afb11ad479ff";
    ref = "refs/heads/nix";
  };

  templates = let drv = fetchurl {
    url = "https://downloads.tuxfamily.org/godotengine/3.3/Godot_v3.3-stable_export_templates.tpz";
    sha256 = "sha256-hWJcL5CMdEb84ToNP4YYhhLG9dwyNBapeTsUmPw/awQ=";
  };
  in runCommandNoCC "Godot" {buildInputs = [unzip];} ''
    unzip ${drv} -d $out
    '';

  nativeBuildInputs = [ my-godot-headless ];

  runCommand "tunnelvr" { buildInputs = [ my-godot-headless ]; } ''
    mkdir $out
    godot-headless --export "Linux/X11" $out
  '';

  outputs = [ "out" ];

#  buildPhase = ''
#    mkdir -p $TMP/.config
#    mkdir -p $TMP/.local/share/godot/templates
#    mkdir -p $TMP/.config/godot/projects/
#    export HOME=$TMP
#    export XDG_CONFIG_HOME="$TMP/.config"
#    export XDG_DATA_HOME="$TMP/.local/share"
#    mkdir -p $TMP/.local/share/godot/
#    ln -s $templates/templates $TMP/.local/share/godot/templates/3.3.stable
#
#    godot-headless --export "Linux/X11" $out
#  '';

#  dontInstall = true;

  meta = with stdenv.lib; {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is fully customizable.
    '';
    homepage = "https://www.gnu.org/software/hello/manual/";
    changelog = "https://git.savannah.gnu.org/cgit/hello.git/plain/NEWS?h=v${version}";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.eelco ];
    platforms = platforms.all;
  };
}

