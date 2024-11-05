# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo >&2 "abort: this script cannot be sourced" >&2 && return 1

source debug.lib.sh || exit 1
source opts.lib.sh  || exit 1
source dicts.lib.sh || exit 1

declare -A options_cfg
suffix=''
lineno=0
dicts::json_to_dict options_cfg suffix lineno "$(cat "options.json")"
#declare -p options_cfg
echo -e -n "$(dicts::dict_to_json options_cfg)" 

opts::init $0
usage_flags="$(opts::generate_flags_help options_cfg)"
usage_config="$(opts::generate_config_help options_cfg)"
declare -A config_file
suffix=''
lineno=0
[ -f "config.json" ] && dicts::json_to_dict config_file suffix lineno "$(cat "config.json")"
echo -e -n "$(dicts::dict_to_json config_file)" 

declare -A option_table="$(opts::parse_options_config options_cfg)"
echo "option_table:" 
echo -e -n "$(dicts::dict_to_json option_table)" 

declare -A config_table="$(opts::parse_options_config_for_env options_cfg)"
echo "config_table:" 
echo -e -n "$(dicts::dict_to_json config_table)" 

declare -A options
# set by init file & envvars
opts::set_options config_table options config_file #f&e
# set by init file 
#opts::set_options config_table options f
## set by env var
#opts::set_options config_table options e
# parse command line options
opts::parse_options option_table options argv "$@"
echo >&2 "remainder of argv: \"$argv\""
# set default values
opts::set_options config_table options config_file d

# show final options
echo -e -n "$(dicts::dict_to_json options)" 

# EOF
