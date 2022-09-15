{ rustPlatform
, pkg-config
, systemd
, nixosTest
, ...
}:
rustPlatform.buildRustPackage {
  pname = "runner-nix";
  version = "0.1.0";
  src = ./.;
  PKG_CONFIG_PATH = "${systemd.dev}/lib/pkgconfig";
  nativeBuildInputs = [ pkg-config ];
  cargoLock.lockFile = ./Cargo.lock;
}
