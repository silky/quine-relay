{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem =
    { pkgs, lib, ... }:
    {
      treefmt = {
        # Nix
        programs.nixpkgs-fmt.enable = true;
      };
    };
}
