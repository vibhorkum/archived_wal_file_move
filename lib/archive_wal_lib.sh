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
# function: print messages with process id
################################################################################
function process_log()
{
   echo "PID: $$ [RUNTIME: $(date +'%m-%d-%y %H:%M:%S')] ${BASENAME}: $*" >&2
}

################################################################################
# function: exit_on_error
################################################################################
function exit_on_error()
{

   process_log "ERROR: $*"
   exit 1
 }

################################################################################
# if_error: display and report error.
################################################################################
function if_error
{
  typeset rc="$1"
  shift
  typeset msg="$*"
  
  if [[ ${rc} -ne 0 ]]
  then
    exit_on_error "$msg; rc=${rc}"
  else
    return 0
  fi
} 

################################################################################
# function: is_wal_greater
#    Function takes two arguments as WAL File name and returns following
#     0: if first WAL is less than second WAL.
#     1: if first WAL is greater than second WAL
#     0: if first and second WAL are same.
################################################################################
function is_wal_greater()
{
  typeset -r FRST_WAL="$1"
  typeset -r SECND_WAL="$2"

  # Parse WAL file name in following:
  # 1. Timeline.
  # 2. Logical XLOG.
  # 3. Physical XLOG.
  typeset -r FRST_TMLINE="0x${FRST_WAL:0:8}"
  typeset -r FRST_LGCL_XLOG="0x${FRST_WAL:8:8}"
  typeset -r FRST_PHYSCL_XLOG="0x${FRST_WAL:16:8}"

  typeset -r SECND_TMLINE="0x${SECND_WAL:0:8}"
  typeset -r SECND_LGCL_XLOG="0x${SECND_WAL:8:8}"
  typeset -r SECND_PHYSCL_XLOG="0x${SECND_WAL:16:8}"

  # Compare Timeline: 
  # If Second Time line is greater than First TimeLine 
  # Then 
  #    Second WAL filename is greater than First. 
  # Else If first time line is greater than Second Timeline
  # Then 
  #     First WAL filename is greater than Second.
  [[ ${SECND_TMLINE?} -gt ${FRST_TMLINE?} ]] && return 0
  [[ ${SECND_TMLINE?} -lt ${FRST_TMLINE?} ]] && return 1

  # Compare Logical Xlog: 
  # If above conditions don't meet 
  # Then, 
  #   If Second Logical XLOG is greater than First 
  #   Then 
  #      Second is greater. 
  #   Else if First Logical XLOG is greater than Second
  #   Then
  #      First is greater.
  [[ ${SECND_LGCL_XLOG?} -gt ${FRST_LGCL_XLOG?} ]] && return 0
  [[ ${SECND_LGCL_XLOG?} -lt ${FRST_LGCL_XLOG?} ]] && return 1

  # Compare Physical Xlog: 
  # If above conditions don't meet 
  # Then, 
  #   If Second Physical XLOG is greater than First 
  #   Then 
  #      Second is greater. 
  #   Else if First Physical XLOG is greater than Second
  #   Then
  #      First is greater.
  [[ ${SECND_PHYSCL_XLOG?} -gt ${FRST_PHYSCL_XLOG?} ]] && return 0
  [[ ${SECND_PHYSCL_XLOG?} -lt ${FRST_PHYSCL_XLOG?} ]] && return 1

  # If none of above conditions meet 
  # Then
  #   First and Second WAL is equal.
  return 0
}

################################################################################
# function: list_incremental_wal
#    Function takes two arguments as ARCHIVE_LOCATION & WAL file.
#    It list WALs newer than named WAL file with ARCHIVE_LOCATION as suffix.
################################################################################
function list_incremental_wal()
{
   typeset -r ARCHIVE_LOCATION="$1"
   typeset -r NAMED_FILE="$2"

   find ${ARCHIVE_LOCATION?} -type f -newer ${NAMED_FILE?}
   if_error "$?" "failed to find new WAL files."
}

################################################################################
# function: lock 
#    Function takes one argument program name.
#    and acquire locks so that parallel process cannot run.
################################################################################
function lock()
{
   typeset -r PROGRAM_NAME="$1"
   typeset -r LOCK_FD=200
   typeset -r LOCK_FILE="/tmp/${PROGRAM_NAME?}.lock"

   # create a lock file.
   eval "exec ${LOCK_FD?}>${LOCK_FILE}"
   
   # acquire lock exclusive lock.
   flock --exclusive --nonblock ${LOCK_FD?} && \
      return 0 || \
      return 1
}

################################################################################
# function: unlock 
#    Function takes one argument program name.
#    and remove locks so that parallel process cannot run.
################################################################################
function unlock()
{
   typeset -r PROGRAM_NAME="$1"
   typeset -r LOCK_FD=200
   typeset -r LOCK_FILE="/tmp/${PROGRAM_NAME?}.lock"
   
   rm -f ${LOCK_FILE}
   flock --unlock ${LOCK_FD} && return 0 || return 1
}
 
################################################################################
# function: is_pg_in_recovery 
#    Function takes arguments port number, username and maintenancedatabase.
#    and returns following:
#     0: PG is in recovery.
#     1: PG is not in recovery.
#    -1: if status is unknow.
################################################################################
function is_pg_in_recovery()
{
    typeset -r F_PGPORT="$1"
    typeset -r F_PGUSER="$2"
    typeset -r F_PGDATABASE="$3"
    typeset -r F_SQL="SELECT pg_is_in_recovery()::text"

    return_value=$(${PGHOME}/bin/psql --tuples-only --no-align --quiet \
                                      --username=${PGUSER}             \
                                      --dbname=${PGDATABASE}           \
                                      --command="${F_SQL}")
    if_error "$?" "failed to get status of recovery."

    [[ ${return_value?} = "true" ]] && return 0 
    [[ ${return_value?} = "false" ]] && return 1
    return -1
}

################################################################################
# function to verify if ip address provided is local ip address
# function takes one argument IP address and verifies ip address of machine using
#   ifconfig -a
################################################################################
function is_local_ip()
{
    typeset -r IP_ADDR="$1"
   
    if [[ "${IP_ADDR?}" = "" ]]
    then
      echo 0
    elif [[ "${IP_ADDR?}" = "localhost" ]]
    then 
      echo 0
    fi
    
   check_ip=$(ifconfig -a|grep ${IP_ADDR?}|wc -l)
   if [[ ${check_ip} -gt 0 ]]
   then
      echo 0
   fi
   echo 1
}
      
################################################################################
# function which copy WAL file if ip address provided is remote then copy in
# remote location
################################################################################
function copy_wal_file()
{
    typeset -r WAL_NAME="$1"
    typeset -r OS_USER="$2"
    typeset -r REMOTE_DIR="$3"
    typeset -r REMOTE_HOST="$4"
    typeset -r TRACK_DIR="$5"
    typeset -r TRACK_FILE="${TRACK_DIR?}/wal_tracker"
    
    if [[ $(is_local_ip ${REMOTE_HOST?}) -eq 0 ]]
    then     
      rsync -a ${WAL_NAME?} ${REMOTE_DIR?}/          
      if_error "$?" "failed to copy wal: ${WAL_NAME?}"
      echo "$(basename ${WAL_NAME?})" > ${TRACK_FILE?}
      return 0
    else
      rsync -a ${WAL_NAME?} ${OS_USER?}@${REMOTE_HOST?}:${REMOTE_DIR?}/   
      if_error "$?" "failed to copy wal: ${WAL_NAME?}"
      echo "$(basename ${WAL_NAME?})" > ${TRACK_FILE?}
      return 0
    fi
    return 1
} 
