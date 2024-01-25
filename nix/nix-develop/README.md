CAVES:

- flake.nix must be checked into the repo
- shell.nix must be checked into the repo
- flake.lock should be in the repo

To use flake caching with direnv autoload:

- .envrc should contain use_flake
- .direnv dir must exist
- direnv > 2.29 or ~/.config/direnv/lib/use_flake.sh from <https://nixos.wiki/wiki/Flakes>

SOURCES:

- <https://nixos.wiki/wiki/Development_environment_with_nix-shell>
- <https://nixos.wiki/wiki/Flakes>
