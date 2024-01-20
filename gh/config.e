#!/bin/execlineb -s0

# file: "config.e"

# initial configuration of gh
# - set ssh as git protocol

fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
                gh auth login --hostname github.com --with-token }
fg { gh config set -h github.com git_protocol ssh }
fg { gh auth status }
gh auth logout

# EOF
