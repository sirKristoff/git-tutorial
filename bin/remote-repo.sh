#!/usr/bin/env bash

APP=$(basename "$0")
REPO_PATH="$(realpath "$(git rev-parse --show-toplevel)/../dummy_lib.git/")"
: ${PREDEF_FILE:=changelog.txt}

## debugging traces
: ${DEBUG_FILE:=/tmp/${APP}-debug.log}
: ${DEBUG_PIPE:=/tmp/${APP}[$$]-debug.pipe}

## init cleanup on program exit
exit_handler() {
  rm -v -f ${DEBUG_PIPE}
  echo "   EXIT: [$$]${APP}:  $(date '+%F %T.%N')"; echo
} >>${DEBUG_FILE}  2>&1
trap 'exit_handler' EXIT

## setup debugging trace stream for logfile and console
echo "  START: [$$]${APP}:  $(date '+%F %T.%N')"  >>${DEBUG_FILE}
mknod ${DEBUG_PIPE} p  >>${DEBUG_FILE} 2>&1  ||  exit 13

## disable printing debug on console
exec 2>/dev/null

## print debug traces to file and console
tee --append ${DEBUG_FILE}  <${DEBUG_PIPE} >&2  &
## open descriptor 13 for debugging purposes
exec 13> ${DEBUG_PIPE}


## -----------------------------------------------------------------------------
##  Usage info
## -----------------------------------------------------------------------------

show_help() {
cat << EOF
Usage: ${APP} [OPTION]...

Perform operations on the local repository located at the specified path.
All options are processed in the order in which they appear.

Mandatory arguments to long options are mandatory for short options too.

Options:
  -n, --name=REPO_PATH     : location of local repository (if option missing:
                             REPO_PATH='${REPO_PATH}'
                             aka. '$(realpath "${REPO_PATH}")')
  -i, --init [-f|--force]  : create repository in \`REPO_PATH'. With --force
                             flag already existing repository will be removed.
  -c, --commit[=FILE]  [-m 'COMMIT_MSG']
                           : make changes in FILE and commit with default commit
                             message. With -m flag, 'COMMIT_MSG' will be
                             prepended to commit message.
                             Default FILE='${PREDEF_FILE}'
  -p, --repo_path          : print location of local repository

Miscellaneous:
      --help              : display this help text and exit

Examples:
  ${APP}  \\
      --name=/tmp/dummy-repo  \\
      --init --force
                   Recreate repository in \`/tmp/dummy-repo' path and do initial
                   commit. Remove existing directory if needed.
  ${APP}  \\
      --commit='CHANGELOG.txt'  \\
      --commit='src/list.txt' -m 'Yet another changes.'
                   For default repo make changes in 'CHANGELOG.txt' file and
                   commit. In second step commit changes in 'src/list.txt' file
                   with commit messsage 'Yet another changes.'
                   (create file or directory if needed).

EOF
}


## -----------------------------------------------------------------------------
##  Functions
## -----------------------------------------------------------------------------

# @brief  Print 80 chars long line
# @param stdin - ignored
# @param var - external variable name
# @param $1 - line_prefix: string to paste on beginning of line
# @param [$2] - separator: line-filling character
# @return  Line filled with separator
# @exit-code  0 - ok
echo-line()
{
  local line_prefix_="${1}"
  local separator_="${2--}"
  if [ -n "$line_prefix_" ]; then
    line_prefix_="${separator_}${separator_}${separator_} ${line_prefix_} ${separator_}"
  fi
  echo -n "${line_prefix_}"

  for ((idx = ${#line_prefix_}; idx < 80; idx++)); do
    echo -n "$separator_"
  done
  echo ${var}
}

## -----------------------------------------------------------------------------
##  Operations
## -----------------------------------------------------------------------------

# @brief  Create repository in \`REPO_PATH'. With --force
#         flag already existing repository will be removed.
# @param REPO_PATH - TODO: external variable name
# @param [$1] - force flag: TODO:
op-init()
{ (
  echo-line "$FUNCNAME"  >&2
  echo "$FUNCNAME: \`$@'" >&2
  local force_="$1"
  ## exit program on any command fails
  set -e

  if [ -n "${force_}" ]; then
    rm -rf "${REPO_PATH}"  >&2
  fi

  mkdir -v -p "${REPO_PATH}"  >&2
  if [ $? -ne 0 ]; then
    return 2
  fi
  cd "${REPO_PATH}"

  git init  >&2
  git config --local --add receive.denyCurrentBranch updateInstead  >&2
  mkdir -p src ; touch src/.keep
  echo "# $(basename "$REPO_PATH") repository" >'README.md'
  echo "$(date '+%F %T.%N'): Initial commit" >"${PREDEF_FILE}"
  git add .  >&2
  git commit -m 'Initial commit'  >&2

  set +e
  echo-line  >&2
)  2>&13
}

# @brief  make changes in FILE and commit with default commit
#         message. With -m flag, 'COMMIT_MSG' will be
#         prepended to commit message.
# @param REPO_PATH - TODO: external variable name
# @param $1 - FILE: TODO: 
# @param [$2] - COMMIT_MSG: TODO: 
op-commit()
{ (
  echo-line "$FUNCNAME"  >&2
  echo "$FUNCNAME: \`$@'"  >&2
  local file_="${1}"
  local dir_="$(dirname "$file_")"
  local message_="${2:-Changes in '${file_##*/}'}"
  ## exit program on any command fails
  set -e

  cd "${REPO_PATH}"

  if ! [ -d "${dir_}" ]; then
    mkdir -v -p "${dir_}"  >&2
  fi
  local file_status_='modified'
  if ! [ -f "${file_}" ]; then
    touch "${file_}"
    file_status_='new file'
  fi
  echo "$(date '+%F %T.%N'): Changes in '${file_}'" >>"${PREDEF_FILE}"
  message_="${message_}

       modified:   changelog.txt"

  if ! [ "${file_}" == "${PREDEF_FILE}" ]; then
    echo "New line." >>"${file_}"
    message_="${message_}
       ${file_status_}:   ${file_}"
  fi

  git add .  >&2
  git commit -m "${message_}"  >&2

  set +e
  echo-line  >&2
)  2>&13
}

## -----------------------------------------------------------------------------
##  Script arguments
## -----------------------------------------------------------------------------

operations_=()
declare -A _flag=()
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;

      ## -n, --name=REPO_PATH
      -n|--name=*)
        if [ "$1" == '-n' ]; then
            REPO_PATH="${2}"
            shift ; shift    # -n REPO_PATH
        else
            REPO_PATH="${1#*=}"
            shift    # --name=REPO_PATH
        fi
        ## for debug purpose
        _flag['name']+="${_flag['name']:+:}${REPO_PATH}"
        ;;

      ## -i, --init [-f|--force]
      -i|--init)
        shift    # -i|--init
        if [ "$1" == '-f' -o "$1" == '--force' ]; then
          shift    # -f|--force
          op-init '--force'
          operations_+=("op-init --force")  ## for debug purpose
        else
          op-init
          operations_+=("op-init")  ## for debug purpose
        fi
        ;;

      ## -c, --commit[=FILE]  [-m 'COMMIT_MSG']
      -c|--commit*)
        if [ "$1" == '-c' ]; then
            shift    # -c
            FILE="${1:-${PREDEF_FILE}}"
            if [ "${FILE}" == '-m' -o "${FILE}" == '-c' -o "${FILE%%=*}" == '--commit' ]; then
              FILE="${PREDEF_FILE}"
            else
              shift    # FILE
            fi
        else
            FILE="${1#--commit=}"
            if [ "${FILE}" == "${1}" ]; then
              FILE="${PREDEF_FILE}"
            fi
            shift    # --commit[=FILE]
        fi
        if [ "$1" == '-m' ]; then
          COMMIT_MSG="${2}"
          shift ; shift    # -m COMMIT_MSG
          op-commit "${FILE}" "${COMMIT_MSG}"
          operations_+=("op-commit '${FILE}' '${COMMIT_MSG}'")  ## for debug purpose
        else
          op-commit "${FILE}"
          operations_+=("op-commit '${FILE}'")  ## for debug purpose
        fi
        ;;

      -p|--repo_path)
        shift    # -p|--repo_path
        realpath "${REPO_PATH}"

        ## for debug purpose
        operations_+=("repo_path: '$(realpath "${REPO_PATH}")'")  ## for debug purpose
        ;;

      -[A-Za-z0-9]*|--*)
        echo "${APP}:${LINENO}: WARNING: Unknown option: \`$1'" >&13
        shift
        ;;

      *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift
        ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

case $# in
  0)
  # no positional argument
    echo -n
    ;;

  *)
  # to many arguments
    echo "${APP}:${LINENO}: ERROR: To many positional arguments: \`$@'" >&13
    exit 2
    ;;
esac


## -----------------------------------------------------------------------------
##  Execution
## -----------------------------------------------------------------------------

(
  echo-line "${APP}:${LINENO}" '='

  echo "  Flags:"
  for flag in "${!_flag[@]}" ; do
    echo "['$flag']='${_flag[$flag]}'"
  done

  echo "  Operations(${#operations_[@]}):"
  for operation in "${operations_[@]}" ; do
    echo "'$operation'"
  done

  echo-line '' '='
) >&13
