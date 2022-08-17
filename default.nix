{ rustPlatform, pkg-config, systemdMinimal }:
rustPlatform.buildRustPackage {
  pname = "runner-nix";
  version = "0.1.0";
  src = ./.;
  SYSTEMD_LIB_DIR = "${systemdMinimal}/lib";
  buildInputs = [ pkg-config ];
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
}
