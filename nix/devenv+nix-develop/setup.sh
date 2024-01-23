# see https://devenv.sh/guides/using-with-flakes/

PROJECT_DIR=DEVENV_PROJECT_USING_FLAKES

mkdir ${PROJECT_DIR}
cp dotenvrc.tmpl ${PROJECT_DIR}/
cp -R data.tmpl ${PROJECT_DIR}/
cd ${PROJECT_DIR}

mv data.tmpl data
mkdir .direnv

git init
nix flake init --template github:cachix/devenv
git add .

cp ../flake.nix.tmpl flake.nix
mv dotenvrc.tmpl .envrc
direnv allow
git add .

# CAVE: the standard .envrc is outdated which leads to errors
# (e.g., it loads an old nix_direnv_version, it does not use
#  watch_file, etc.)
