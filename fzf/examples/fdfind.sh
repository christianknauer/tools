fdfind --type f --strip-cwd-prefix |
   fzf \
   --prompt '\ > ' \
   --bind 'ctrl-d:unbind(ctrl-d)+reload(fdfind --type d --strip-cwd-prefix)+transform-prompt(echo d\>\ )+rebind(ctrl-f)' \
   --bind 'ctrl-f:unbind(ctrl-f)+reload(fdfind --type f --strip-cwd-prefix)+transform-prompt(echo \ \>\ )+rebind(ctrl-d)' \
   +m --reverse --scheme=path --prompt '> ' --border=rounded --preview 'fzf-preview {}' --preview-window 'right,40%,+{2}+3/3,~3' --height 90% --header-first --header 'ranger'
