{
  description = "Astral Engine";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.astralengine.url = "git+https://github.com/infernoamaruq/astralengine?submodules=1";
  inputs.astralengine.flake = false;

  outputs = { self, nixpkgs, flake-utils, astralengine }:
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
        git
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
            src =  astralengine;

          nativeBuildInputs = commonNativeBuildInputs pkgs;
          buildInputs = commonBuildInputs pkgs;

          configurePhase = "cmake -B build";
          buildPhase = "cmake --build build";
          installPhase = "cmake --install build --prefix $out";
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
