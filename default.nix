{ rustPlatform
, systemd
, pkg-config
, ...
}:
rustPlatform.buildRustPackage {
  pname = "runner-nix";
  version = "0.1.0";
  src = ./.;
  buildInputs = [ systemd ];
  nativeBuildInputs = [ pkg-config ];
  cargoLock.lockFile = ./Cargo.lock;
}
