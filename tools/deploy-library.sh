#!/bin/bash

check_commands() {
  if ! command -v rstext &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "rstext"
    return 100
  fi
  if ! command -v gawk &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "gawk"
    return 100
  fi
  if ! command -v deploypress-client &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "deploypress-client"
    return 100
  fi
  if ! command -v jq &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "jq"
    return 100
  fi
  if ! command -v curl &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "curl"
    return 100
  fi
  if ! command -v docker &>/dev/null
  then
    printf -- "ERROR: missing '%s' command ...\n" "docker"
    return 100
  fi
}

_push_section() {
  [[ -z ${1:-} ]] || __SECTION+=( "${1}" )
}

_pop_section() {
  unset __section
  declare -g __section
  [[ ${#__SECTION[@]} -ge 1 ]] && { printf -v __section -- "%s" "${__SECTION[-1]}" && unset __SECTION[-1]; }
}

__begin() {
  local section header collapsed
  [[ ${#} -ge 2 ]] || return 0
  section="${1}"
  header="${2}"
  collapsed=""
  if [[ ${section::1} == "-" ]]
  then
    section="${section:1}"
    collapsed="[collapsed=true]"
  fi
  [[ ${3:-} == "no-stack" ]] || _push_section "${section}"
  printf -- "\e[0Ksection_start:%s:%s%s\r\e[0K%s\n" "$(date +%s)" "${section}" "${collapsed}" "${header}"
}

end__() {
  local section
  if [[ -n ${1:-} ]]
  then
    section="${1}"
  elif _pop_section
  then
    section="${__section}"
  else
    return 0
  fi
  printf -- "\e[0Ksection_end:%s:%s\r\e[0K" "$(date +%s)" "${section}"
}

end_all__() {
  while _pop_section
  do
    end__ "${__section}"
  done
}

end_ci__() {
  end_all__
  if [[ -z ${__CI_OUTPUT_ENDED:-} ]]
  then
    declare -g __OUTPUT_ENDED=1
    printf -- "\e[0Ksection_end:%s:%s\r\e[0K" "$(date +%s)" "_ci_output_"
  fi
}

__failed() {
  local rc=$?
  trap - ERR
  trap - EXIT
  end_ci__
  __begin panic "Failed ..."
    printf -- "\n"
    rstext red:bwhite FAILED
    [[ -z ${1:-} ]] || _printf -- "{R}FATAL:{Y} %s ...\n" "${1}"
  end__
  exit 100
}

__final() {
  local rc=$?
  trap - ERR
  trap - EXIT
  if [[ ${rc} -ne 0 ]]
  then
    end_ci__
    __begin panic "Failed ..."
      printf -- "\n"
      rstext red:bwhite FAILED
    end__
    exit ${rc}
  fi
  exit 0
}

config_error() {
  __failed "unable to parse CI configuration"
}

# usage: _printf "{R}RED {B}BLUE {G}GREEN {Y}YELLOW {N}NEUTRAL" ... etc
_printf() {
local _text
  if [[ ${1:-} == "--" ]]
  then
    shift
  fi
  if [[ -z ${1:-} ]]
  then
    set -- "\n"
  fi
  if [[ ${COLOR:-} == "no" ]]
  then
    local _RED=''
    local _GREEN=''
    local _YELLOW=''
    local _BLUE=''
    local _MAGENTA=''
    local _CYAN=''
    local _NEUTRAL=''
    local _BOLD=''
    local _UNDERLINE=''
    local _BLINK=''
  else
    local _RED='\e[31m'
    local _GREEN='\e[32m'
    local _YELLOW='\e[33m'
    local _BLUE='\e[34m'
    local _MAGENTA='\e[35m'
    local _CYAN='\e[36m'
    local _NEUTRAL='\e[0m'
    local _BOLD='\e[1m'
    local _UNDERLINE='\e[4m'
    local _BLINK='\e[5m'
  fi
  _text="$1"
  shift
  if [[ $_text =~ \{N\}$ ]]
  then
   _text="${_text%\{N\}}"
  else
   _text="${_text}{N}"
  fi
  _text="${_text//\{G\}/$_GREEN}"
  _text="${_text//\{B\}/$_BLUE}"
  _text="${_text//\{Y\}/$_YELLOW}"
  _text="${_text//\{R\}/$_RED}"
  _text="${_text//\{C\}/$_CYAN}"
  _text="${_text//\{M\}/$_MAGENTA}"
  _text="${_text//\{\*\}/$_BOLD}"
  _text="${_text//\{\_\}/$_UNDERLINE}"
  _text="${_text//\{\+\}/$_BLINK}"
  _text="${_text//\{N\}/$_NEUTRAL}"
  # shellcheck disable=SC2059
  printf -- "$_text" "$@"
}

deploy_process_response() {
local payload line artifacts
  payload="${1}"
  declare -a RESULT
  readarray -t RESULT <<< "${payload}"
  if [[ ${#RESULT[@]} -lt 1 ]]
  then
    printf -- "FATAL: result error\n"
    exit 100
  fi

  unset RESPONSE
  unset OUTPUT
  unset STATUS

  declare -g RESPONSE=""
  declare -g OUTPUT=""
  declare -g STATUS=""
  declare artifacts=""
  for line in "${RESULT[@]}"
  do
    case "${line}" in
      STATUS:*)
        STATUS="${line#STATUS:}"
        ;;
      RESPONSE:*)
        RESPONSE="$(echo "${line#RESPONSE:}" | base64 -d)"
        ;;
      OUTPUT:*)
        OUTPUT="$(echo "${line#OUTPUT:}" | base64 -d)"
        ;;
      ARTIFACTS:*)
        artifacts="$(echo "${line#ARTIFACTS:}" | base64 -d)"
      ;;
     *)
        printf -- "WARNING: unsupported response data ...\n"
    esac
  done

  if  [[ -z ${STATUS} ]]
  then
    printf -- "FATAL: malformed response (STATUS expected) ...\n"
    exit 180
  fi

  if ! [[ ${STATUS} =~ ^[0-9]+$ ]]
  then
    printf -- "FATAL: malformed response (STATUS code is not a number) ...\n"
    exit 180
  fi

  unset ARTIFACTS
  ARTIFACTS=()
  if [[ -n ${artifacts} ]]
  then
    readarray -t ARTIFACTS <<< "${artifacts}"
  fi

  if [[ ${STATUS} != "200" ]]
  then
    return
  fi
  local file base
  for artifact in "${ARTIFACTS[@]}"
  do
    file="$(echo -n "${artifact}" | cut -d: -f1)"
    file="$(echo -n "${file}" | base64 -d)"
    base="$(dirname "${file}")"
    mkdir -p "${base}"
    echo -n "${artifact}" | cut -d: -f2 | base64 -d > "${file}"
  done
}

declare -ga __SECTION=()
trap __failed ERR
trap __final EXIT
