{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Needed for 'swift' which is broken in 25.11 and unstable.
    nixpkgs2505.url = "github:nixos/nixpkgs/nixos-25.05";

    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      (inputs.import-tree ./nix);
}
