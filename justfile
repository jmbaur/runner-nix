build:
	cargo build

run: build
	systemd-socket-activate -l8000 -l8080 ./target/debug/runner-nix --adapter none --command hello

watch:
	fd -e rs | entr sh -c 'just run'
