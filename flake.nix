{
  description = "A basic flake to help develop Solidity smart contracts";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/monthly"; # Use monthly branch for permanent releases
  };
  outputs = { self, nixpkgs, utils, foundry }: 
    utils.lib.eachDefaultSystem (system: 
      let 
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ 
            foundry.overlay 
          ];
        };
      in {
        devShell = with pkgs; mkShell {
          buildInputs = [
            solc-select
            foundry-bin 
            slither-analyzer
            echidna
          ];

          shellHook = ''
            export PS1="[dev] $PS1"
          '';
        };
      }
    );
}
