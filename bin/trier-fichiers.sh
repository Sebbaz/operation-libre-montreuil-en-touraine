#!/bin/bash

#    Prepare a electronic documents analysis
#    Walk into a folder to extract File System metadata (ext4) to a csv file,
#    and generate a flat symlink view into a single folder.
#    Copyright (C) 2016-2017 Sébastien BAZAUD
#    Related projects:
#      Regards Citoyens https://github.com/regardscitoyens/operation-libre-aiglun
#      Internet Cube https://github.com/labriqueinternet GPL V3 for bash libraries
#
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>."


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

######################
# Checking functions #
######################

function check_args() {

  if [ ! -z "${opt_imgpath}" ]; then
    if [ ! -r "${opt_imgpath}" ]; then
      exit_usage "File given to -f cannot be read"
    fi

    if [[ ! "${opt_imgpath}" =~ \.img(\.tar\.xz)?$ ]]; then
      exit_usage "Filename given to -f must end with .img or .img.tar.xz"
    fi

    if [ -z "${opt_gpgpath}" ]; then
      if [ -r "${opt_imgpath}.asc" ]; then
        info "Local GPG signature file found"
        opt_gpgpath="${opt_imgpath}.asc"
      fi
    else
      if [[ "${opt_imgpath}" =~ \.img$ ]] ; then
        exit_usage "File given to -g cannot be used for checking the file given to -f (not archive version)"
      fi

      if [ "$(basename "${opt_gpgpath}")" != "$(basename "${opt_imgpath}").asc" ] ; then
        exit_usage "Based on filenames, file given to -g seems not correspond to the file given to -f"
      fi
    fi
  fi
}

#######################
# Cleanning functions #
#######################

function cleaning_exit() {
  local status=$?
  local error=${1}

  trap - EXIT ERR INT

  if $opt_debug && [ "${status}" -ne 0 -o "${error}" == error ]; then
    debug "There was an error, press Enter for doing cleaning"
    read -s

    if [ -d "${tmp_dir}" ]; then
      debug "Cleaning: ${tmp_dir}"
      rm ${tmp_dir}*
    fi
  fi
}

function cleaning_ctrlc() {
  echo && cleaning_exit error
  exit 1
}

function check_and_create_dir() {
    if [ ! -d ${1} ]; then
      warn "Directory ${1} does not exist, creating it."
      mkdir ${1}
    fi

    if [ "$(ls -A ${1})" ]; then
      warn "Directory ${1} is not empty, cleanning it? (yes/no)"
      read confirm && echo

      if [ "${confirm}" == "yes" ]; then
        debug "Cleaning: ${1}"
        rm ${1}*
      else
        cleaning_ctrlc
      fi
    fi
}

####################
# Metadata Getters #
####################

function get_last_access_date() {
  echo $(stat -c '%y' ${1} | cut -d" " -f1)
}

function getFileMimeType() {
  file --mime-type ${1} | cut -d":" -f2 | sed "s/ //"
}

function getFileSize() {
  local nbBlocks=$(stat -c '%b' ${1})
  local blockSize=$(stat -c '%B' ${1})
  local fileSize=$(($nbBlocks * $blockSize))
  echo $((${fileSize} / 1024))
}

function get_rel_dir() {
  local full_dir_path=$(dirname ${1})
  echo $(echo ${full_dir_path} | sed "s#${sources_dir}##")
}

function getFileExtension() {
  echo ${1} | rev | cut -d"." -f 1 | rev
}

####################
# Global variables #
####################
#save the old Internal Field Separator to work with spaces
savIFS=$IFS

# Project dir vars
root=$(pwd)"/"
sources_dir=${root}"sources/"
tmp_dir=${root}"tmp/symbolicLinks/"
outDir=${root}"data/"
outCsvFileName="FSMetadata.csv"

# option variables
opt_src_path=${sources_dir}
opt_out_path=${outDir}${outCsvFileName}
opt_debug=false

##############
# The Script #
##############

# Catch interruptions
trap cleaning_exit EXIT ERR
trap cleaning_ctrlc INT

preamble

# get bash options
while getopts "i:o:dh" opt; do
  case $opt in
    i) opt_src_path=$OPTARG ;;
    o) opt_out_path=$OPTARG ;;
    d) opt_debug=true ;;
    h) exit_usage ;;
    \?) exit_usage ;;
  esac
done

# Check if tmp dir is empty and created
check_and_create_dir $tmp_dir

IFS=$'\n'

# Output the first line of csv
echo "LastModified;Directories;FileName;FileExtension;FileMimeType;FileEncoding;FileSize(kB);Hash" > ${opt_out_path}

# recursively loop over sources, get metadata, output to csv Files and
for file in $(find "${opt_src_path}" -type f -follow)
do
  info "Reading file ${file}."
  debug "Getting last access time..."
  lastAccessTime=$(get_last_access_date ${file})
  debug "Getting basename..."
  fileBasename=$(basename ${file})
  debug "Getting file extention..."
  fileExt=$(getFileExtension ${file})
  debug "Getting mime type..."
  fileMimeType=$(getFileMimeType ${file})
  debug "Getting file size..."
  fileSize=$(getFileSize ${file})
  debug "Getting relative dir..."
  relDir=$(get_rel_dir ${file})
  debug "Getting encoding..."
  fileEncoding=$(file -b --mime-encoding ${file})
  debug "Generating ID: pathname..."
  cleanedPath=$(echo ${relDir} | sed -e "s#[/ ]#_#g")
  debug "Generating ID: filename..."
  cleanedFileName=$(echo ${fileBasename} | sed "s# #_#g")
  debug "Generating ID: concatenate dirname and filename..."
  idFile="$cleanedPath""_$cleanedFileName"
  debug "Getting file hash..."
  fileHash=$(md5sum ${file} | cut -d" " -f 1)
  debug "Generate outfile csv raw..."
  echo "$lastAccessTime;$relDir;$fileBasename;$fileExt;$fileMimeType;$fileEncoding;$fileSize;$fileHash" >> ${opt_out_path}
  debug "Create sym link..."
  ln -s ${file} ${tmp_dir}${idFile}
  info "Ok."
done

IFS=${savIFS}

nb_lig_out=$(wc -l ${opt_out_path} | cut -d" " -f 1)
nb_file_read=$((${nb_lig_out}-1))

info "Done. Processed: ${nb_file_read} files."