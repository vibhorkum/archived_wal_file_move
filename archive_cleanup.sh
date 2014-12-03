#!/bin/bash

################################################################################
# Copyright EnterpriseDB Cooperation
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in
#      the documentation and/or other materials provided with the
#      distribution.
#    * Neither the name of PostgreSQL nor the names of its contributors
#      may be used to endorse or promote products derived from this
#      software without specific prior written permission.
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#  Author: Vibhor Kumar
#  E-mail ID: vibhor.aim@gmail.com
################################################################################
# quit on any error
set -e
# verify any  undefined shell variables
set -u

################################################################################
# set some environment/common variables 
################################################################################
BASENAME=$(basename $0)
DIRNAME="$(dirname $0)"
CLEANUP_PERMITTED="NO"

################################################################################
# source archive_wal library and configuration file
################################################################################
if [[ -r ${DIRNAME?}/lib/archive_wal_lib.sh ]]
then
   source ${DIRNAME?}/lib/archive_wal_lib.sh
else
   echo "ERROR: unable to source archive_wal_lib.sh"
   exit 1
fi

if [[ -r ${DIRNAME?}/etc/config.sh ]]
then
   source ${DIRNAME?}/etc/config.sh
else
  echo "ERROR: unable to source config.sh"
fi

################################################################################
# get input WAL filename
################################################################################
INPUT_WAL="$1"

################################################################################
# check we got wal file name as input
################################################################################
[[ ! -z ${INPUT_FILE?} ]]
if_error "$?" "no input of WAL file."

WAL_NAME="$(echo "${INPUT_WAL?}"|cut -d"." -f1)"

################################################################################
# check tracker file exists: 
#     if not don't do anything and exit
#     if exists, then find the in progress WAL file and clean accordingly.  
################################################################################
if [[ ! -f ${TRACK_FILE?} ]]
then
   process_log "tracker file doesn't exists skipping WAL cleanup."
   exit 0
else
    LAST_IN_PROGRESS=$(cat ${TRACK_FILE?}|grep "progress" |cut -d"." -f1)
    LAS_COPIED_WAL=$(cat ${TRACK_FILE?}|grep "done" |cut -d"." -f1)
    
    if [[ ! -z ${LAST_IN_PROGRESS?} ]]
    then
      is_wal_greater "${WAL_NAME?}" "${LAST_IN_PROGRESS?}" && \
      CLEANUP_PERMITTED="YES"  ||                             \
      exit 0
    elif [[ ! -z ${LAS_COPIED_WAL?} ]]
    then
      is_wal_greater "${WAL_NAME?}" "${LAST_IN_PROGRESS?}" && \
      CLEANUP_PERMITTED="YES"  ||                             \
      exit 0
    fi      
     
if

[[ "${CLEANUP_PERMITTED?}" = "YES" ]] && \
${PGHOME?}/bin/pg_archivecleanup ${ARCHIVE_LOCATION?} "${WAL_NAME?}"
exit 0

