nix-shell -p zig --command 'cd .
zig cc -o hello hello.c -target x86_64-linux-musl
zig cc -o hello.exe hello.c -target x86_64-windows'
rm -rf ~/.cache/zig
