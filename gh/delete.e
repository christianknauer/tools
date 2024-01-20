#!/bin/execlineb -s0

# file: "delete.e"

# delete a repo on github.com (name is from the current dir)

# set env vars (does not require substitutions)
getcwd _fcwd 
backtick _script { basename ${0} }
backtick _ghtoken { ph show @credentials/github.io/tokens/gh --field password }

# apply "prepocessor" definitions/substitutions to abbreviate some execline commands
# also perform initial substitutions to get env vars substituted 
 
multisubstitute {
       multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
       importas -ui fcwd _fcwd
       importas -ui script _script
       importas -ui ghtoken _ghtoken
}

backtick _cwd { basename ${fcwd} }

# 2. substitution round

multisubstitute {
       importas -ui cwd _cwd
       define usage "Usage: ${script} [GLOBAL OPTIONS]

  Delete the repo named "${cwd}" on github.com.

  Global options:
            -h : show this help

"
}

#$fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
#           gh auth login --hostname github.com --with-token }
$fg { pipeline { echo ${ghtoken} } gh auth login --hostname github.com --with-token }
$fg { gh config set -h github.com git_protocol ssh }
$fg { gh auth status }
$fg { gh repo delete ${cwd} }
gh auth logout

# EOF
