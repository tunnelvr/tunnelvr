{ stdenv, lib, godot-headless }:

stdenv.mkDerivation rec {
  pname = "tunnelvr-headless";
  version = "6bbd23bf9f719dc7cdfd9de08addb62adbd52a62";

  src = fetchGit {
    url = "https://github.com/goatchurchprime/tunnelvr.git";
    rev = "6bbd23bf9f719dc7cdfd9de08addb62adbd52a62";
#    ref = "refs/tags/v0.6.0";
    ref = "refs/heads/master";
#    sha256 = lib.fakeSha256;
  };

  nativeBuildInputs = [ godot-headless ];

  outputs = [ "out" ];

  buildPhase = ''
    godot-headless --export "Linux/X11" $out/bin/${pname}
  '';

#    mkdir -p "$out/bin"
#  doCheck = true;

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
