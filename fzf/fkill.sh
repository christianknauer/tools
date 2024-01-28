# shellcheck shell=bash

fkill()
{
  local signal='HUP'
  local users
  users=$(id -nu)
  users="${users:0:7}"
  local query
  local pid_only

  local selection line entry
  local uid pid cmd

  hash getopt 2>/dev/null || {
    echo >&2 -e "abort: getopt is required"
    return 1
  }
  hash fzf 2>/dev/null || {
    echo >&2 -e "abort: fzf is required"
    return 1
  }
  hash hck 2>/dev/null || {
    echo >&2 -e "abort: hck is required"
    return 1
  }

  local options
  options=$(getopt -o hp02I3Q9KTp --long query: -- "$@") && ec=$?
  [ "$ec" -eq 0 ] || {
    echo >&2 "abort: incorrect options provided"
    return 1
  }
  eval set -- "$options"
  while true; do
    case "$1" in
      -h)
        local usage
        read -r -d '' usage <<EOF
  Usage: ${FUNCNAME[0]} [OPTIONS] <query> 

  Searches the list of running processes with fzf. If an entry is selected the 
  corresponding process is killed unless the -p option is provided. In that case
  the pid of the selected process is printed to stdout.

  A process is killed by sending a HUP signal. An alternative kill signal can 
  be specified with the -2,-I (INT), -3,-Q (QUIT), -9, -K (KILL) options.

  Only the processes of the current user are searched, unless the -0 option is 
  provided. In that case all processes are searched.

  Arguments:
	<query>: Set the initial fzf query to <query> (optional).

  Options (all optional):
  	-h: Show this help.

	-0: Search all processes (of all users).

	-p: Only print pid of the selected process. 

        -2,-I: Send INT signal.
	-3,-Q: Send QUIT signal
	-9,-K: Send KILL signal

	--query <query>: Set the initial fzf query to <query>
EOF
        echo -e "$usage" 1>&2
        return
        ;;
      -p)
        pid_only=1
        ;;
      -0)
        users='.*'
        ;;
      -2)
        signal='INT'
        ;;
      -I)
        signal='INT'
        ;;
      -3)
        signal='QUIT'
        ;;
      -Q)
        signal='QUIT'
        ;;
      -9)
        signal='KILL'
        ;;
      -K)
        signal='KILL'
        ;;
      -T)
        signal='TERM'
        ;;
      --query)
        shift # The arg is next in position args
        query="$1"
        ;;
      --)
        shift
        break
        ;;
      *)
        echo >&2 "abort: incorrect options provided ($1)"
        return 1
        ;;
    esac
    shift
  done

  query="$1"

  local pattern='^([^ ]*) ([0-9]*) (.*)'
  selection=$(ps -aef | hck -f1,2,8- | tr -s '[:blank:]' ' ' | tail -n+2 |
    while IFS=$'\n' read -r line; do
      [[ ! "${line}" =~ ${pattern} ]] && echo "abort: regexp does not match" && return
      uid="${BASH_REMATCH[1]}"
      pid="${BASH_REMATCH[2]}"
      cmd="${BASH_REMATCH[3]}"
      [[ "${uid}" =~ ${users} ]] && printf "%8s    %5d    %s\n" "$uid" "$pid" "$cmd"
    done |
    fzf --query "$query")
  [ -z "$selection" ] && return
  entry=$(echo "$selection" | tr -s '[:blank:]' ' ' | sed -e 's/^ //g')

  [[ ! "${entry}" =~ ${pattern} ]] && echo "abort: regexp does not match" && return
  uid="${BASH_REMATCH[1]}"
  pid="${BASH_REMATCH[2]}"
  cmd="${BASH_REMATCH[3]}"

  [ -z "$pid" ] && return

  if [ -z "$pid_only" ]; then
    echo "kill -$signal $pid"
    printf " %8s:   %s\n" "$uid" "$cmd"
    kill -"$signal" "$pid"
  else
    echo "$pid"
  fi
}
