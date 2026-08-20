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
}
