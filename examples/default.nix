{
  craneLib,
  stdenv,
  lib,
  hax,
  fstar,
  hacl-star,
  hax-env,
  jq,
  proverif,
}: let
  commonArgs = import ./commonArgs.nix {inherit craneLib lib;};
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
  craneLib.mkCargoDerivation (commonArgs
    // {
      inherit cargoArtifacts;
      pname = "hax-examples";
      doCheck = false;
      buildPhaseCargoCommand = ''
        cd examples
        eval $(hax-env)
        export CACHE_DIR=$(mktemp -d)
        export HINT_DIR=$(mktemp -d)
        export SHELL=${stdenv.shell}
        make clean # Should be a no-op (see `filter` above)
        # Need to inject `HAX_VANILLA_RUSTC=never` because of #472
        sed -i "s/make -C limited-order-book/HAX_VANILLA_RUSTC=never make -C limited-order-book/g" Makefile
        make
      '';
      buildInputs = [
        hax hax-env fstar jq
        (proverif.overrideDerivation (_: {
          patches = [ ./proverif-psk/pv_div_by_zero_fix.diff ];
        }))
      ];
    })
