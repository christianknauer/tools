#!/usr/bin/env bats
  
EXE=gen.sh

# arg prefix
APF="__${EXE}__arg"

# bats setup & teardown

setup() {
  # open file for logging
  exec 9> "bats-${EXE}.log"  #open fd 9.
  echo "bats ${EXE} started $(date) - setting up" >&9
  # add source directory to PATH
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  export PATH="$DIR/..:$PATH"
}

teardown() {
  echo "finished $(date) - tearing down" >&9
  cleanup
}

# helper functions

random_arg() {
  echo "${APF}${RANDOM}"
}

cleanup() {
  rm -rf ${APF}*.{ini,kdbx,mc,sd}
}

# tests

@test "sourcing fails" {
    run source ${EXE}
    [ "${status}" -ne 0 ]
}

@test "invalid entropy fails" {
    run ${EXE} -e 222 
    [ "${status}" -ne 0 ]
}

@test "without argument fails" {
    run ${EXE} 
    [ "${status}" -ne 0 ]
}

@test "existing files fails without -f" {
    ARG=$(random_arg)
    cleanup
    run ${EXE} "${ARG}"
    run ${EXE} "${ARG}"
    [ "${status}" -ne 0 ]
    cleanup
}

@test "existing files succeeds with -f" {
    ARG=$(random_arg)
    cleanup
    run ${EXE} "${ARG}"
    run ${EXE} -f "${ARG}"
    [ "${status}" -eq 0 ]
    cleanup
}

@test "manifest verification succeeds" {
    ARG=$(random_arg)
    cleanup
    run ${EXE} -p 12345 "${ARG}"
    run ${EXE} -p 12345 -v -m "${ARG}.mc" "${ARG}"
    [ "${status}" -eq 0 ]
    cleanup
}

# EOF
