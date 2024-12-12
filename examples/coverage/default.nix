{
  stdenv,
  lib,
  hax,
  coqPackages,
  gnused,
  craneLib,
  bat,
  coqGeneratedCore ? import ../../proof-libs/coq/coq {inherit stdenv coqPackages;},
}:
let
  commonArgs = import ../commonArgs.nix {inherit craneLib lib;};
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
  craneLib.mkCargoDerivation (commonArgs
    // {
      inherit cargoArtifacts;
      pname = "coverage";
      doCheck = false;
      buildPhaseCargoCommand = ''
        cd examples/coverage
        cargo hax into coq

        cd proofs/coq/extraction
        echo -e "-R ${coqGeneratedCore}/lib/coq/user-contrib/Core Core\n$(cat _CoqProject)" > _CoqProject
        coq_makefile -f _CoqProject -o Makefile
        make
      '';
      buildInputs = [
        hax
        coqPackages.coq-record-update
        coqPackages.coq
        gnused
      ];
    })


    # COQLIB
