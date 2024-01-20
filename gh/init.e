#!/bin/execlineb -s0

# file: "init.e"

# create a private repo on github.com from the current dir
# - basename of cwd is the repository name 
# - initialize .gitattributes (transcrypt)
# - initialize .gitignore
# - initialize README.md

# set env vars (does not require substitutions)
getcwd _fcwd 
backtick _script { basename ${0} }

# 1. substitution round
# - apply "prepocessor" definitions/substitutions to abbreviate some execline commands
# - perform substitutions to get env vars substituted 
 
multisubstitute {
 multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
 importas -ui fcwd _fcwd
 importas -ui script _script
}

# set new env vars with data from 1. round
backtick _cwd { basename ${fcwd} }

# 2. substitution round
# - perform substitutions to get new env vars substituted 
# - substitute string macros
multisubstitute {
  importas -ui cwd _cwd
  define ERROR "ERROR ${script}:"
  define INFO  "INFO  ${script}:"
  define USAGE "Usage: ${script} [GLOBAL OPTIONS]

  Creates a private repo named "${cwd}" on github.com 
  from the current directory (${fcwd}).

  - initialize .gitattributes for transcrypt
  - initialize .gitignore
  - initialize README.md

  Global options:
            -h : show this help

"
  define GITATTRIBUTES "
# the following files are encrypted by transcrypt 
# (https://github.com/elasticdog/transcrypt)
**/__secrets/** filter=crypt diff=crypt merge=crypt
# EOF
"
}

# show help message if called with arguments
ifelse { test $# -gt 0 } { 
  $fg { echo $USAGE } exit 0
}

# sanity check
ifelse { test -d .git } { i
  $fg { echo $ERROR ".git directory already exits" } exit 1 
}

# set new env vars 
# this is deferred until here because it requires a password (we want to ask for
# passwords only when all sanity checks are ok)

backtick _ghtoken { ph show @credentials/github.io/tokens/gh --field password }

# 3. substitution round to get these env vars substituted 
multisubstitute {
 importas -ui ghtoken _ghtoken
}

$fg { echo $INFO "creating repo ${cwd} in ${fcwd}" } 

$fg { mkdir "__secrets" }
$fg { touch "__secrets/.keep" }

$fg { heredoc 0 "
# the following files are encrypted by transcrypt 
# (https://github.com/elasticdog/transcrypt)
**/__secrets/** filter=crypt diff=crypt merge=crypt
# EOF
" tee .gitattributes }

$fg { heredoc 0 "
# ignore the following files 
# (1 file or pattern per line)
# EOF
" tee .gitignore }

$fg { heredoc 0 "
# Foobar

Foobar is a Python library for dealing with word pluralization.

## Installation

Use the package manager [pip](https://pip.pypa.io/en/stable/) to install foobar.

```bash
pip install foobar
```

## Usage

```python
import foobar

# returns 'words'
foobar.pluralize('word')

# returns 'geese'
foobar.pluralize('goose')

# returns 'phenomenon'
foobar.singularize('phenomena')
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)
" tee README.md }

$fg { git init }
$fg { transcrypt -c aes-256-cbc -y }
$fg { git add . }
$fg { git commit -m "repository initialized (${script})" }
# $fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
#                gh auth login --hostname github.com --with-token }
$fg { pipeline { echo ${ghtoken} } gh auth login --hostname github.com --with-token }
$fg { gh config set -h github.com git_protocol ssh }
$fg { gh auth status }
$fg { gh repo create ${cwd} --private --source=. --remote=upstream }
$fg { git push --set-upstream upstream master }
$fg { transcrypt --display }
gh auth logout

# EOF
