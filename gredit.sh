#!/bin/bash
# [ 0x19e Networks ]
#  http://0x19e.net
# Author: Robert W. Baumgartner <rwb@0x19e.net>
#
# Allows editing a range of files by locating similar lines.
# Two grep patterns are used to locate lines: the first allows narrowing the context to a block of
# text that contains the actual target line. This is done using a regular expression and an integer
# defining how many lines surrounding each match to include when the next search is performed.
# The final search simply greps for a given target string, which must be an exact match.
# Every match is then processed to construct edit commands.
#
# TODO: Allow searching single files.

EDIT_COMMAND="editor"
DEFAULT_CTX_LINES=3

GREP_LOCATION="*"
CONTEXT_REGEX=""
TARGET_STRING=""
CONTEXT_LINES=${DEFAULT_CTX_LINES}

#CONTEXT_REGEX="EOF"
#CONTEXT_REGEX="^[\s[A-Za-z0-9\-\_]+ocsp[A-Za-z0-9\-\_]+\s]$"
#TARGET_STRING="sed\s\-e"
#TARGET_STRING="authorityInfoAccess"

exit_script()
{
  # Default exit code is 1
  local exit_code=1
  local re

  re='^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$'
  if echo "$1" | grep -qE "$re"; then
    exit_code=$1
    shift
  fi

  re='[[:alnum:]]'
  if echo "$@" | grep -iqE "$re"; then
    if [ "$exit_code" -eq 0 ]; then
      echo "INFO: $*"
    else
      echo "ERROR: $*" 1>&2
    fi
  fi

  # Print 'aborting' string if exit code is not 0
  [ "$exit_code" -ne 0 ] && echo "Aborting script..."

  exit "$exit_code"
}

usage()
{
    # Prints out usage and exit.
    sed -e "s/^    //" -e "s|SCRIPT_NAME|$(basename "$0")|" << "EOF"
    USAGE

    Edit a configuration settings across multiple files in a directory using grep.

    SYNTAX
            SCRIPT_NAME [OPTIONS] ARGUMENTS

    ARGUMENTS

      path                  The location to search within.

    OPTIONS

     -c, --context <regex>  A RegEx to locate lines close to the desired target.
     -t, --target <expr>    An expression identifying the target lines to process.
     -s, --search <lines>   The number of lines around context matches to search within.
     -r, --recursive        Recurse sub-directories (if target is a folder).
     -l, --list             List matching files but do not edit.

     --dry-run              Do not invoke editor; print out commands instead.
     --vim                  Use Vim instead of the default editor.

     -v, --verbose          Make the script more verbose.
     -h, --help             Prints this usage.

    EXAMPLES

      - To search and edit AIA OCSP settings within an OpenSSL configuration:
        `~/gredit.sh -c '^[\s[A-Za-z0-9\-\_]+ocsp[A-Za-z0-9\-\_]+\s]$' -t 'authorityInfoAccess' -s 20 ./ssl-config/`

EOF

    exit_script "$@"
}

test_arg()
{
  # Used to validate user input
  local arg="$1"
  local argv="$2"

  if [ -z "$argv" ]; then
    if echo "$arg" | grep -qE '^-'; then
      usage "Null argument supplied for option $arg"
    fi
  fi

  if echo "$argv" | grep -qE '^-'; then
    usage "Argument for option $arg cannot start with '-'"
  fi
}

test_path_arg()
{
  # test directory argument
  local arg="$1"
  local argv="$2"

  test_arg "$arg" "$argv"

  if [ -z "$argv" ]; then
    argv="$arg"
  fi

  if [ ! -e "$argv" ]; then
    usage "Specified path does not exist: $argv"
  fi
}

test_number_arg()
{
  local arg="$1"
  local argv="$2"

  test_arg "$arg" "$argv"

  if [ -z "$argv" ]; then
    argv="$arg"
  fi

  re='^[0-9]+$'
  if ! [[ "$argv" =~ $re ]] ; then
    usage "Option for argument $arg must be numeric."
  fi
}

VERBOSITY=0
#VERBOSE=""
#check_verbose()
#{
#  if [ $VERBOSITY -gt 1 ]; then
#    VERBOSE="-v"
#  fi
#}

#argc=$#
[ $# -gt 0 ] || usage

i=1
TARGET_PATH=""
GREP_RECURSIVE="false"
LIST_MODE="false"
DRY_RUN="false"
USE_VIM="false"

# process arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--context)
      test_arg "$1" "$2"
      shift
      CONTEXT_REGEX="$1"
      shift
    ;;
    -t|--target)
      test_arg "$1" "$2"
      shift
      TARGET_STRING="$1"
      shift
    ;;
    -s|--search)
      test_number_arg "$1" "$2"
      shift
      CONTEXT_LINES="$1"
      shift
    ;;
    -v|--verbose)
      ((VERBOSITY++))
      #check_verbose
      i=$((i+1))
      shift
    ;;
    -vv)
      ((VERBOSITY++))
      ((VERBOSITY++))
      #check_verbose
      i=$((i+2))
      shift
    ;;
    -vvv)
      ((VERBOSITY++))
      ((VERBOSITY++))
      ((VERBOSITY++))
      #check_verbose
      i=$((i+3))
      shift
    ;;
    --dry-run)
      DRY_RUN="true"
      shift
    ;;
    --vim)
      USE_VIM="true"
      shift
    ;;
    -l|--list)
      LIST_MODE="true"
      shift
    ;;
    -r|--recursive)
      GREP_RECURSIVE="true"
      shift
    ;;
    -h|--help)
      usage
    ;;
    *)
      if [ -n "${TARGET_PATH}" ]; then
        usage "Cannot specify multiple search locations."
      fi
      test_path_arg "$1"
      TARGET_PATH="$(readlink -m "${1}")"
      shift
    ;;
  esac
done

if [ "${USE_VIM}" == "true" ]; then
  EDIT_COMMAND="vim"
fi

if [ "${DRY_RUN}" == "true" ]; then
  PRE_CMD="echo"
fi

GREP_EXT_OPTS=""
GREP_CTX_OPTS="-P"
if [ "${GREP_RECURSIVE}" == "true" ]; then
  GREP_EXT_OPTS="${GREP_EXT_OPTS} -r"
fi
if [ -z "${TARGET_STRING}" ]; then
  usage "Must specify a target string to search for."
fi
if [ -z "${CONTEXT_REGEX}" ]; then
  if [ "${CONTEXT_LINES}" -eq ${DEFAULT_CTX_LINES} ]; then
    CONTEXT_LINES=1
  fi
  GREP_CTX_OPTS=""
  CONTEXT_REGEX="${TARGET_STRING}"
fi

if [ -z "${TARGET_PATH}" ]; then
  TARGET_PATH="$(readlink -m .)"
fi

#if [ -d "${TARGET_PATH}" ]; then
#pushd "${TARGET_PATH}" > /dev/null 2>&1
#else
#GREP_LOCATION="${TARGET_PATH}"
#fi

if [ ! -d "${TARGET_PATH}" ]; then
GREP_LOCATION="${TARGET_PATH}"
else
GREP_LOCATION="${TARGET_PATH}/${GREP_LOCATION}"
fi

GREP_COMMAND="grep -P ${GREP_EXT_OPTS} -n ${GREP_CTX_OPTS} '${CONTEXT_REGEX}' ${GREP_LOCATION} -A${CONTEXT_LINES}"
if [ -n "${TARGET_STRING}" ] && [ ! -d "${TARGET_STRING}" ]; then
  GREP_COMMAND="${GREP_COMMAND} | grep '${TARGET_STRING}'"
fi

if [ $VERBOSITY -gt 0 ]; then
  echo "Target string : ${TARGET_STRING}"
  echo "Target path   : ${TARGET_PATH}"
  echo "Grep location : ${GREP_LOCATION}"
  echo "Grep command  : ${GREP_COMMAND}"
fi

GREP_RESULTS=$(bash -c "${GREP_COMMAND} | grep -vP '^Binary\sfile'")
if [ -n "${TARGET_STRING}" ] && [ ! -d "${TARGET_STRING}" ]; then
  GREP_RESULTS=$(echo "${GREP_RESULTS}" | grep "${TARGET}")
fi

if ! TMP_RESULTS=$(echo "${GREP_RESULTS}" | grep -P "${TARGET_STRING}" | grep -v -P "(\-|\:)[0-9]+(\-|\:)([\s]+)?\#" | sed -r "s/\-([0-9]+)\-/\:\1\:/"); then
  echo >&2 "ERROR: Failed to perform search."
  exit 1
fi
if [ -z "${TMP_RESULTS}" ]; then
  echo >&2 "No result(s) found."
  exit 1
fi

if [ "${LIST_MODE}" == "true" ]; then
  if [ -d "${TARGET_PATH}" ]; then
    MATCHES=$(echo "${TMP_RESULTS}" | awk -F: '{ print $1 }' | uniq -c | sed -e 's/^[ \t]*//')
    echo "${MATCHES}" | while read -r line; do
      if [ ! -z "${line}" ]; then
      echo "${line}" | awk -F' ' "{ printf \"Found %d match(es): %s\n\", \$1, \$2 }";
      fi
    done
    # echo "${TMP_RESULTS}" | awk -F: '{ printf "Found match(es): %s\n", $1 }'
    popd > /dev/null 2>&1
  else
    echo "Found match(es): ${TARGET_PATH}"
  fi

  exit 0
fi

if [ ! -d "${TARGET_PATH}" ]; then
  AWK_CMD="{ printf \"+%s %s\n\", \$1, \"${TARGET_PATH}\" }"
else
  AWK_CMD="{ printf \"+%s %s\n\", \$2, \$1 }"
fi

IFS=$'\n'; for l in $(echo "${TMP_RESULTS}" | awk -F: "${AWK_CMD}"); do ${PRE_CMD} bash -c "${EDIT_COMMAND} ${l}"; done

#if [ -d "${TARGET_PATH}" ]; then
#popd > /dev/null 2>&1
#fi

exit 0
