{
  description = "Shyrogan's widgets that sucks, re-usable with Flakes.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = "0.1.0";
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages = let
          agsBuildScreen = name: main: style: pkgs.stdenv.mkDerivation {
            inherit name version;
            src = ./.;

            buildInputs = with pkgs; [ ags esbuild dart-sass makeWrapper ];
            buildPhase = ''
              runHook preBuild
              
              esbuild --bundle ${main} \
                --outfile=config.js \
                --external:resource://\* \
                --external:gi://\* --format=esm

              sass ${style} style.css

              runHook postbuild
            '';
            installPhase = ''
              runHook preInstall

              mkdir -p $out
              cp config.js $out
              
              cp -r assets/ $out/assets/
              cp style.css $out/style.css
              cat $out/style.css

              makeWrapper ${pkgs.ags}/bin/ags \
                $out/bin/${name} \
                --add-flags "-c $out/config.js"

              runHook postInstall
            '';
          };
        in rec {
          # greeter = agsBuildScreen "greeter" "src/greeter/app.ts";
          desktop = agsBuildScreen "desktop" "./src/apps/desktop/index.ts" "./styles/desktop.scss";
          default = desktop;
        };
      }
    );
}
