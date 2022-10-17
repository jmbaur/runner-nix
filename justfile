run:
	cargo build
	fd -e rs | entr -c sh -c 'cargo build && systemd-socket-activate -l8000 -l8080 ./target/debug/runner-nix --adapter none --command hello'
