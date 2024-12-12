{
  craneLib,
  lib,
}:
let
  matches = re: path: !builtins.isNull (builtins.match re path);
in
{
  version = "0.0.1";
  src = lib.cleanSourceWith {
    src = craneLib.path ./..;
    filter = path: type:
      # We include only certain files. FStar files under the example
      # directory are listed out. Same for proverif (*.pvl) files.
      (   matches ".*(Makefile|.*[.](rs|toml|lock|diff|fsti?|pv))$" path
          && !matches ".*examples/.*[.]fsti?$" path
      ) || ("directory" == type);
  };
  doCheck = false;
  cargoVendorDir = craneLib.vendorMultipleCargoDeps {
    cargoLockList = [
      ./Cargo.lock
      ../Cargo.lock
    ];
  };
}
