{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    nixpkgs-fmt
  ];
  packages = [ 
    bats
    go-task
    lefthook
    mdl
    shellcheck 
    shfmt
    yamlfmt
  ];
  shellHook =
  ''
    echo "Hello shell"
  '';
}
