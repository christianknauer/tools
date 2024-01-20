#!/bin/execlineb -s0

# file: "test.e"

# testing

backtick -E script { basename ${0} }
getcwd -E cwdfull 
backtick -E cwd { basename ${cwdfull} }

fg { echo "${0}:${script}:${cwd}:${1}" }
heredoc 0 "
# first line
this is a cool string
# EOF
" tee test.conf

# EOF
