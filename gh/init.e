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
# - "prepocessor" definitions/substitutions to abbreviate some execline commands
# - text color definitions
# - perform substitutions to get env vars substituted 
 
multisubstitute {
 multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
 multidefine -d : "\033[1;34m:\033[0;37m:\033[1;31m:\033[1m:\033[0m" { BLUE WHITE RED BOLD OFF }
 importas -ui fcwd _fcwd
 importas -ui script _script
}

# set new env vars & auto-substitute (2. substitution)
backtick -E cwd { basename ${fcwd} }

# 3. substitution round
# - substitute string macros
multisubstitute {
  define ERROR "${RED}ERROR${OFF} ${WHITE}${BOLD}${script}${OFF}:"
  define INFO  "${BLUE}INFO ${OFF} ${WHITE}${BOLD}${script}${OFF}:"
  define USAGE "Usage: ${script} [GLOBAL OPTIONS]

  Creates a private repo named "${cwd}" on github.com from the 
  current directory (${fcwd}).

  - initialize .gitattributes for transcrypt
  - initialize .gitignore
  - initialize README.md

  Global options:
            -h : show this help
"
  define GITATTRIBUTES 
"# the following files are encrypted by transcrypt 
# (https://github.com/elasticdog/transcrypt)
**/__secrets/** filter=crypt diff=crypt merge=crypt
# EOF"
  define GITIGNORE
"# ignore the following files 
# (1 file or pattern per line)
# EOF"
  define READMEMD
"# Foobar

Foobar is a Python library for dealing with word pluralization.

## Installation

Use the package manager [pip](https://pip.pypa.io/en/stable/) to install foobar.

```bash
pip install foobar
```

## Usage

```python
import foobar

# returns 'phenomenon'
foobar.singularize('phenomena')
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)"
}
  
# show help message if called with arguments
ifelse { test $# -gt 0 } { 
  $fg { echo $USAGE } exit 0
}

# sanity check
ifelse { test -d .git } {
  $fg { echo $ERROR ".git directory already exits" } exit 1 
}
$fg { echo $INFO "creating repo ${cwd} in ${fcwd}" } 

# do the work
$fg { mkdir "__secrets" }
$fg { touch "__secrets/.keep" }
$fg { redirfd -w 1 .gitattributes echo ${GITATTRIBUTES} }
$fg { redirfd -w 1 .gitignore echo ${GITIGNORE} }
$fg { redirfd -w 1 README.md echo ${READMEMD} }
$fg { git init }
$fg { transcrypt -c aes-256-cbc -y }
$fg { git add . }
$fg { git commit -m "repository initialized (${script})" }
$fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
                 gh auth login --hostname github.com --with-token }
$fg { gh config set -h github.com git_protocol ssh }
$fg { gh auth status }
$fg { gh repo create ${cwd} --private --source=. --remote=upstream }
$fg { git push --set-upstream upstream master }
$fg { transcrypt --display }
emptyenv -oP
gh auth logout

# EOF
