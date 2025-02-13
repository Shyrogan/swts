{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    ags.url = "github:Aylur/ags";
  };
  
  outputs = { nixpkgs, ags, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in with pkgs;
    {
      devShells.${system}.default = mkShell {
        buildInputs = [ ags.packages.${system}.agsFull ];
      };
      packages.${system}.default = ags.lib.bundle {
        inherit pkgs;
        name = "swts";
        src = ./.;
        entry = "apps/desktop.ts";
        gtk4 = false;
        extraPackages = with ags.packages.${system}; [ io battery astal3 hyprland tray gjs wireplumber ];
      };
    };
}
