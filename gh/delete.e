#!/bin/execlineb -s0

# file: "delete.e"

# delete a repo on github.com (name is from the current dir)

# set env vars (does not require substitutions)
getcwd _fcwd 
backtick _script { basename ${0} }

# 1. substitution round
# - constants for config (github user name)
# - "prepocessor" definitions/substitutions to abbreviate some execline commands
# - color definitions
# - perform substitutions to get env vars substituted 
 
multisubstitute {
  define ghuname christianknauer
  multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
  #
  multidefine -d : "\033[1;34m:\033[0;37m:\033[1;31m:\033[1m:\033[0m" { BLUE WHITE RED BOLD OFF }
  #
  importas -ui fcwd _fcwd
  importas -ui script _script
}

# set new env vars & auto-substitute (2. substitution)
backtick -E cwd { basename ${fcwd} }

# 3. substitution round
# - command paths
# - string macros
multisubstitute {
  define repo ${ghuname}/${cwd}
  define ERROR "${RED}ERROR${OFF} ${WHITE}${BOLD}${script}${OFF}:"
  define INFO  "${BLUE}INFO ${OFF} ${WHITE}${BOLD}${script}${OFF}:"
  define USAGE "${BOLD}Usage${OFF}: ${script} [GLOBAL OPTIONS]

  Delete the repo named "${repo}" on github.com.

  Global options:
            -h : show this help

"
}
  
# show help message if called with arguments
ifelse { test $# -gt 0 } { 
  $fg { echo $USAGE } exit 0
}

# get confirmation from user
ifelse -n { whiptail --title "${script} - delete github.com repo" 
                     --yesno "Proceed with deletion of repo ${repo}?" 
		     --yes-button "yes" --no-button "no" 0 0 } {
  $fg { echo $ERROR "user requested abort" } exit 2 
}

# do the work

$fg { pipeline { ph show @credentials/github.io/tokens/gh --field password }
               gh auth login --hostname github.com --with-token }
$fg { gh config set -h github.com git_protocol ssh }
$fg { gh repo delete ${cwd} --confirm }
# clean up
emptyenv -oP
pipeline { echo Y } gh auth logout -h github.com

# EOF
