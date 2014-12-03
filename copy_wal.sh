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
# creating trap to remove lock in case script finish or errors
################################################################################
trap "unlock ${BASENAME?};exit " SIGHUP SIGINT SIGTERM

################################################################################
# verify if standby is still in recovery mode."
################################################################################
is_pg_in_recovery "${PGPORT?}" "${PGUSER?}" "${PGDATABASE?}"
if_error "$?" "Standby is not in recovery mode. exiting."

################################################################################
# acquire lock first before copying wal.
################################################################################
process_log "acquiring lock."
lock "${BASENAME?}"
if_error "$?" "one process is already running. not able to acquire lock."

################################################################################
# verify if its one time running. If its first run then copy all file
################################################################################
if [[ ! -f ${TRACK_FILE?} ]]
then
   process_log "seems first time execution of archiving."
   process_log "copying all wal file"
   for wal in $(ls -1t ${ARCHIVE_LOCATION?}/ )
   do
     process_log "copying wal: ${wal?} on "${REMOTE_HOST?}
     copy_wal_file "${wal?}"          \
                   "${OS_USER?}"      \
                   "${REMOTE_USER?}"  \
                   "${REMOTE_HOST?}"  \
                   "${TRACK_DIR?}"
     if_error "$?" "not able to copy wal file ${wal?}"
     exit 0
   done
fi

################################################################################
# check where we left and copy new files.
################################################################################
LAST_IN_PROGRESS=$(cat ${TRACK_FILE?}|grep "progress" |cut -d"." -f1)
if [[ -z ${LAST_IN_PROGRESS?} ]]
then
   LAST_COPIED_WAL=$(cat ${TRACK_FILE?}|grep "done" |cut -d"." -f1)
   for wal in "$(list_incremental_wal "${ARCHIVE_LOCATION?}" \
                                      "${LAST_COPIED_WAL?}")"
   do
    process_log "copying wal: ${wal?}"
    copy_wal_file "${wal?}"         \
                  "${OS_USER?}"     \
                  "${REMOTE_USER?}" \
                  "${REMOTE_HOST?}" \
                  "${TRACK_DIR?}"
    if_error "$?" "not able to copy wal file ${wal?}"
   done
   exit 0
else
   for wal in "${LAST_IN_PROGRESS?} $(list_incremental_wal "${ARCHIVE_LOCATION?}" \
                                                           "${LAST_IN_PROGRESS?}")"
   do
     process_log "copying wal: ${wal?}"
     copy_wal_file "${wal?}"         \
                   "${OS_USER?}"     \
                   "${REMOTE_USER?}" \
                   "${REMOTE_HOST?}" \
                   "${TRACK_DIR?}"
     if_error "$?" "not able to copy wal file ${wal?}"
   done
   exit 0
fi

