{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    nixpkgs-fmt
  ];
  shellHook =
  ''
    echo "Hello shell"
    export DEADBEEFAFFE="66666"
  '';
}
