# Nix setup for quine-relay

Build everything:

``` sh
nix build github:silky/quine-relay/nix
# Or clone it and run `nix build`
```

You can also build individual steps:

``` sh
nix build .#php-to-png
