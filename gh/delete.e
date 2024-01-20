#!/bin/execlineb -s0

# file: "delete.e"

# delete a repo on github.com (name is from the current dir)

getcwd   -E cwdfull 
backtick -E cwd     { basename ${cwdfull} }

fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
                gh auth login --hostname github.com --with-token }
fg { gh config set -h github.com git_protocol ssh }
fg { gh auth status }
fg { gh repo delete ${cwd} }
gh auth logout

# EOF
