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

      commonNativeBuildInputs = pkgs: with pkgs; [
        cmake
        gcc
        gnumake
        pkg-config
        python3
      ];
      
      commonBuildInputs = pkgs: with pkgs; [
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
      
      runtimePackages = pkgs: with pkgs; [
        alsa-lib
        libpulseaudio
        pipewire
        vulkan-loader
        vulkan-headers
        vulkan-tools
        mesa
      ];

    in {
      packages = forAllSystems (pkgs: {
        default = pkgs.stdenv.mkDerivation {
          name = "AstralEngine";
            src = builtins.fetchGit {
              url = "https://github.com/infernoamaruq/astralengine";
              submodules = true;
            };

          nativeBuildInputs = commonNativeBuildInputs pkgs;
          buildInputs = commonBuildInputs pkgs;
        };
      });
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = commonNativeBuildInputs pkgs;
          buildInputs = commonBuildInputs pkgs;
          packages = runtimePackages pkgs;

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
