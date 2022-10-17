{ rustPlatform, systemd, pkg-config, lib, ... }:
let
  cargoTOML = lib.importTOML ./Cargo.toml;
  pname = cargoTOML.package.name;
  version = cargoTOML.package.version;
in
rustPlatform.buildRustPackage {
  inherit pname version;
  src = ./.;
  buildInputs = [ systemd ];
  nativeBuildInputs = [ pkg-config ];
  cargoLock.lockFile = ./Cargo.lock;
}
