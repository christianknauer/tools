find -L . \( -path '*/\.*' -o -fstype 'dev' -o -fstype 'proc' \) -prune \
  -o -print 2>/dev/null | sed 1d | cut -b3- | fzf +m --reverse --scheme=path --prompt '> ' --border=rounded --preview 'fzf-preview {}' --preview-window 'right,40%,+{2}+3/3,~3' --height 90% --header-first --header 'ranger'
