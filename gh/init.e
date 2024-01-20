#!/bin/execlineb -s0

# file: "init.e"

# create a private repo on github.com from the current dir
# - basename of cwd is the repository name 
# - initialize .gitattributes (transcrypt)
# - initialize .gitignore
# - initialize README.md

ifelse { test -d .git } { fg { echo "ERROR: .git directory already exits, aborting" } exit 1 }

getcwd   -E cwdfull 
backtick -E script  { basename ${0} }
backtick -E cwd     { basename ${cwdfull} }

fg { mkdir "__secrets" }
fg { touch "__secrets/.keep" }

fg { heredoc 0 "
# the following files are encrypted by transcrypt 
# (https://github.com/elasticdog/transcrypt)
**/__secrets/** filter=crypt diff=crypt merge=crypt
# EOF
" tee .gitattributes }

fg { heredoc 0 "
# ignore the following files 
# (1 file or pattern per line)
# EOF
" tee .gitignore }

fg { heredoc 0 "
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

fg { git init }
fg { transcrypt -c aes-256-cbc -y }
fg { git add . }
fg { git commit -m "repository initialized (${script})" }
fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
                gh auth login --hostname github.com --with-token }
fg { gh config set -h github.com git_protocol ssh }
fg { gh auth status }
fg { gh repo create ${cwd} --private --source=. --remote=upstream }
fg { git push --set-upstream upstream master }
fg { transcrypt --display }
gh auth logout

# EOF
