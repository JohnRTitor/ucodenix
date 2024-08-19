{
  stdenv,
  lib,
  fetchFromGitHub,
  makeWrapper,
}:
stdenv.mkDerivation {
  pname = "amd-ucodegen";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "AndyLavr";
    repo = "amd-ucodegen";
    rev = "0d34b54e396ef300d0364817e763d2c7d1ffff02";
    sha256 = "pgmxzd8tLqdQ8Kmmhl05C5tMlCByosSrwx2QpBu3UB0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  makeTarget = "";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp amd-ucodegen $out/bin/
    runHook postInstall
  '';

  meta = {
    description = "This tool generates AMD microcode containers as used by the Linux kernel.";
    homepage = "https://github.com/AndyLavr/amd-ucodegen";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
