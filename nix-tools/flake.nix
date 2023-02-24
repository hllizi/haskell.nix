{
  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, haskell-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # pkgs = let
        pkgs = import nixpkgs {
          inherit system;
          inherit (haskell-nix) config;
          overlays = [ haskell-nix.overlay ];
        };

        # don't use cabalProject here, it's too strict and accidentally evaluates IDF for other architectures 
        project = pkgs: pkgs.haskell-nix.cabalProject' rec {
          src = ./.;
          compiler-nix-name = "ghc8107";
        };

        flake = pkgs: (project pkgs).flake { };

        mkBinaryTarball = drv:
          pkgs.runCommand drv.name { nativeBuildInputs = [ pkgs.gnutar ]; } ''
            mkdir -p $out
            tar czv -C ${drv} --dereference . > $out/${drv.name}.tgz
            mkdir -p $out/nix-support
            echo file binary-dist $out/${drv.name}.tgz > $out/nix-support/hydra-build-products
          '';

        projectComponents = prj: comp-type:
          pkgs.lib.concatMap
            (package:
              if package != null then
                pkgs.lib.attrValues (package.components.${comp-type} or { })
              else
                [ ])
            (pkgs.lib.attrValues prj.hsPkgs);

      in
      pkgs.haskell-nix.haskellLib.combineFlakes ""
        (
          { "native-" = flake pkgs; }
          // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64)
            (pkgs.lib.listToAttrs
              (map (pkgs': pkgs.lib.nameValuePair "${pkgs'.hostPlatform.config}-" (flake pkgs'))
                [ pkgs.pkgsCross.musl64 pkgs.pkgsCross.aarch64-multiplatform-musl ]))
        ));

  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://cache.zw3rk.com"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
    allow-import-from-derivation = "true";
  };
}
