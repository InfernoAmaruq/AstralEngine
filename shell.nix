{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
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

  LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
    vulkan-loader
    alsa-lib
    pipewire
    libpulseaudio
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
}
