{
  description = "A basic flake to help develop Solidity smart contracts";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/monthly"; # Use monthly branch for permanent releases
    solc = {
      url = "github:hellwolf/solc.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, utils, foundry, solc }: 
    utils.lib.eachDefaultSystem (system: 
      let 
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ 
            foundry.overlay 
            solc.overlay
          ];
        };
      in {
        devShell = with pkgs; mkShell {
          buildInputs = [
            solc_0_8_19
            solc_0_8_23
            (solc.mkDefault pkgs solc_0_8_23) # Specify a default solc version
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
