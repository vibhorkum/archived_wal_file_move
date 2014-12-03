################################################################################
# user allowed variable changed section
################################################################################

TRACK_DIR="/tmp"                                       # directory to be used for tracking
ARCHIVE_LOCATION="/var/lib/ppas/9.4/data/archive_wal"  # archived WAL location
OS_USER="postgres"                                     # OS user which will be use for rsync to remote server.
REMOTE_DIR="/tmp/wal"                                  # Remote server directory name
REMOTE_HOST="/tmp"                                     # Remote host name
PGHOME="/usr/ppas-9.4"                                 # PPAS/PostgreSQL home directory
PGPORT="5444"                                          # PPAS database port
PGUSER="postgres"                                      # PPAS database username
PGDATABASE="postgres"                                  # PPAS maintenance database

################################################################################
# Derived variables
################################################################################
TRACK_FILE="${TRACK_DIR}/wal_tracker"
ARCHIVE_TRANSFER_SCRIPT="copy_wal.sh"
