#!/bin/bash

#    Prepare a numerical documents analysis
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

####################
# Global variables #
####################
#save the old Internal Field Separator to work with spaces
savIFS=$IFS

# Project dir vars
BASE=$(dirname $(dirname $0))/
sources_dir=${BASE}"sources/"
tmp_dir=${BASE}"tmp/symbolicLinks/"
outDir=${BASE}"data/"
outCsvFileName="FSMetadata.csv"

# option variables
opt_src_path=${sourcrootes_dir}
opt_out_path=${outDir}${outCsvFileName}
opt_debug=false

#############
# LIbraries #
#############

. ${BASE}/bin/lib/helpers.sh

######################
# Checking functions #
######################

function check_args() {
  if [ ! -z "${opt_src_path}" ]; then
    if [ ! -r "${opt_src_path}" ]; then
      exit_usage "File given to -o cannot be read"
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

  if ${opt_debug} && [ "${status}" -ne 0 -o "${error}" == error ]; then
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

##############
# The Script #
##############

# Catch interruptions
trap cleaning_exit EXIT ERR
trap cleaning_ctrlc INT

preamble

# get bash options
while getopts "i:o:dh" opt; do
  case ${opt} in
    i) opt_src_path=$OPTARG
       sources_dir=${opt_src_path};;
    o) opt_out_path=$OPTARG ;;
    d) opt_debug=true ;;
    h) exit_usage ;;
    \?) exit_usage ;;
  esac
done

# Check if tmp dir is empty and created
check_and_create_dir ${tmp_dir}

IFS=$'\n'

# Output the first line of csv
echo "LastModified;Directories;FileName;FileExtension;FileMimeType;FileEncoding;FileSize(kB);Hash" > ${opt_out_path}

# recursively loop over sources, get metadata, output to csv Files and
for file in $(find "${sources_dir}" -type f -follow)
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