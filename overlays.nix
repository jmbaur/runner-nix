inputs: with inputs; {
  default = _: prev: {
    runner-nix = prev.callPackage ./runner-nix.nix { };
  };
}
