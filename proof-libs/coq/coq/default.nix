{
  stdenv ? (import <nixpkgs> {}).stdenv,
  coqPackages ? (import <nixpkgs> {}).coqPackages,
}:
stdenv.mkDerivation {
  name = "hax-coq-generated-core";
  src = ./generated-core;
  buildPhase = ''
    coq_makefile -f _CoqProject -o Makefile
    make
  '';
  installPhase = ''
    export DESTDIR=$out
    make install
    mv $out/nix/store/*/lib $out
    rm -rf $out/nix
  '';
  buildInputs = [
    coqPackages.coq-record-update
    coqPackages.coq
  ];
}
