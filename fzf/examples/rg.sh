: | rg_prefix='rg --column --line-number --no-heading --color=always --smart-case' \
    fzf \
        --bind 'start:reload:$rg_prefix ""' \
        --bind 'change:reload:$rg_prefix {q} || true' \
        --bind 'enter:become(echo {} | cut -d: -f1)' \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --ansi --disabled \
   +m --reverse --scheme=path --prompt '> ' --border=rounded --preview 'fzf-preview {}' --preview-window 'right,40%,+{2}+3/3,~3' --height 90% --header-first --header 'ranger'
