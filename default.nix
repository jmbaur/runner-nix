{ rustPlatform, llvmPackages_latest, systemd, pkg-config, lib, ... }:
let
  cargoTOML = lib.importTOML ./Cargo.toml;
  pname = cargoTOML.package.name;
  version = cargoTOML.package.version;
in
rustPlatform.buildRustPackage {
  inherit pname version;
  src = ./.;
  buildInputs = [ systemd ];
  nativeBuildInputs = [ llvmPackages_latest.bintools pkg-config ];
  RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
  cargoLock.lockFile = ./Cargo.lock;
}
