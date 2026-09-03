{
  description = "Astral Engine";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cmake
            gcc
            gnumake
            pkg-config
            python3
          ];

          buildInputs = with pkgs; [
            libx11
            libxrandr
            libxinerama
            libxcursor
            libxi
            libxext
            libxkbcommon
            xorgproto
            libxfixes
            libxrender
            libxdamage
            libxtst
            libxcb
            curl
          ];

          packages = with pkgs; [
            alsa-lib
            libpulseaudio
            pipewire
            vulkan-loader
            vulkan-headers
            vulkan-tools
            mesa
          ];

          LD_LIBRARY_PATH = with pkgs; pkgs.lib.makeLibraryPath [
            vulkan-loader
            alsa-lib
            pipewire
            libpulseaudio
          ];
        };
      });

    };
}
