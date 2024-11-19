{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ags.url = "github:Aylur/ags/v2";
  };

  outputs = { self, nixpkgs, flake-utils, ags, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      ags-bin = ags.packages.${system}.agsFull;
      dependencies = with pkgs; [ ags-bin morewaita-icon-theme ];
      
      mkAgsBin = app-name: pkgs.stdenv.mkDerivation {
        name = "swts-${app-name}";
        src = ./apps/${app-name}/.;
        buildInputs = dependencies ++ [ pkgs.makeWrapper ];
        installPhase = ''
          mkdir -p $out/config
          mkdir -p $out/bin
          cp -r ./* $out/config/
          ln -s ${pkgs.morewaita-icon-theme}/share/icons/MoreWaita ./assets/icons
          ls -la ${pkgs.morewaita-icon-theme}/share/icons/MoreWaita

          makeWrapper ${ags-bin}/bin/ags \
            $out/bin/swts-${app-name} \
            --add-flags " run $out/config"
        '';
      };
    in {
      packages = rec {
        bar = mkAgsBin "bar";
        default = bar;
      };
      devShells = {
        default = pkgs.mkShell {
          buildInputs = [ ags-bin ];
        };
      };
    });
}
