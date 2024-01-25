{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    nixpkgs-fmt
  ];
  packages = [ 
    bats
    lefthook
    mdl
    shellcheck 
    shfmt
  ];
  shellHook =
  ''
    echo "Hello shell"
  '';
}
