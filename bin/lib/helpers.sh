#!/usr/bin/env bash


###########
# Helpers #
###########

function preamble() {
  local confirm=no

  echo -ne "\e[91m"
  echo "THERE IS NO WARRANTY FOR THIS PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW."
  echo "EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER"
  echo "PARTIES PROVIDE THE PROGRAM \"AS IS\" WITHOUT WARRANTY OF ANY KIND, EITHER"
  echo "EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF"
  echo "MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE"
  echo "QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE"
  echo "DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION."
  echo -e "\e[39m"

}

function show_usage() {
  echo -e "\e[1mOPTIONS\e[0m" >&2
  echo -e "  \e[1m-i\e[0m \e[4mpath\e[0m" >&2
  echo -e "     Path of source folder (e.g. /dev/sdb, /dev/mmcblk0)" >&2
  echo -e "     \e[2mDefault: ./sources/\e[0m" >&2
  echo -e "  \e[1m-o\e[0m \e[4mfile\e[0m" >&2
  echo -e "     Name of output CSV file" >&2
  echo -e "     \e[2mDefault : ./data/FSMetadata.csv\e[0m" >&2
  echo -e "  \e[1m-d\e[0m" >&2
  echo -e "     Enable debug messages" >&2
  echo -e "  \e[1m-h\e[0m" >&2
  echo -e "     Show this help" >&2
}

function exit_error() {
  local msg=${1}
  local usage=${2}

  if [ ! -z "${msg}" ]; then
    echo -e "\e[31m\e[1m[ERR] $1\e[0m" >&2
  fi

  if [ "${usage}" == usage ]; then
    if [ -z "${msg}" ]; then
      echo -e "\n       \e[7m\e[1m Metadata FS Extractor \e[0m\n"
    else
      echo
    fi

    show_usage
  fi

  exit 1
}

function exit_usage() {
  local msg=${1}
  exit_error "${msg}" usage
}

function exit_normal() {
  exit 0
}

function info() {
  local msg=${1}

  echo -e "\e[32m[INFO] $(date -R): ${msg}\e[0m" >&2
}

function warn() {
  local msg=${1}

  echo -e "\e[93m[WARN] $(date -R): ${msg}\e[0m" >&2
}

function debug() {
  local msg=${1}

  if $opt_debug; then
    echo -e "\e[33m[DEBUG] $(date -R): ${msg}\e[0m" >&2
  fi
}
