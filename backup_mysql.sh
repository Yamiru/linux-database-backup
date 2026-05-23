#!/bin/bash
# =============================================================================
#  Linux Database Backup Script
# -----------------------------------------------------------------------------
#  GitHub:  https://github.com/Yamiru/linux-database-backup
#  Author:  Yamiru <https://yamiru.com/>
#  License: MIT
# -----------------------------------------------------------------------------
#  Description:
#    Compressed per-database MySQL/MariaDB backups (gzip).
#    Each database is dumped into its own .sql.gz inside a timestamped folder.
#    Backups and logs are stored in separate, configurable directories.
#    Both backups and logs are rotated by count (keeps last N items).
# =============================================================================

# === Storage paths (can point to different folders / different disks) ===
BACKUP_DIR="/opt/linux-database-backup/backups"   # where .sql.gz archives go
LOG_DIR="/opt/linux-database-backup/logs"         # where log files go

# === MySQL credentials file ===
# Copy .my.cnf.example -> .my.cnf and fill in your credentials.
MY_CNF="/opt/linux-database-backup/.my.cnf"

# === Rotation settings ===
RETENTION_COUNT=5   # number of backup folders to keep
LOG_RETENTION=5     # number of log files to keep

# === Safety settings ===
MIN_FREE_MB=500   # warn if free space in BACKUP_DIR is below this (MB); 0 = disable

# === Excluded databases ===
# System databases are excluded by default. Add your own names below if needed.
# One name per line. Lines starting with # are comments, empty lines are ignored.
EXCLUDE_DBS=$(cat <<'EOF'
information_schema
performance_schema
mysql
sys
test
EOF
)

# =============================================================================
#  Below this line you normally don't need to change anything.
# =============================================================================

DATE=$(date +"%F_%H%M%S")
TODAYS_BACKUP_DIR="$BACKUP_DIR/$DATE"
LOG_FILE="$LOG_DIR/backup_${DATE}.log"

# pipefail so mysqldump | gzip correctly reports a mysqldump failure
set -o pipefail

# Ensure storage directories exist before first log() call
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Logging helper – writes to both stdout and the log file
log() { echo "[$(date +'%F %T')] $*" | tee -a "$LOG_FILE"; }

mkdir -p "$TODAYS_BACKUP_DIR"
log "--- MySQL Backup started ---"

# -----------------------------------------------------------------------------
# Disk space check (advisory – does not abort)
# -----------------------------------------------------------------------------
if [ "$MIN_FREE_MB" -gt 0 ]; then
    FREE_MB=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [ -n "$FREE_MB" ] && [ "$FREE_MB" -lt "$MIN_FREE_MB" ]; then
        log "WARNING: Free space on $BACKUP_DIR is ${FREE_MB} MB (below ${MIN_FREE_MB} MB threshold)."
    fi
fi

# Check config
if [ ! -f "$MY_CNF" ]; then
    log "ERROR: Missing $MY_CNF"
    log "Create it by copying .my.cnf.example -> .my.cnf"
    exit 1
fi

# .my.cnf must have safe permissions, otherwise the mysql client ignores it
CNF_PERMS=$(stat -c '%a' "$MY_CNF" 2>/dev/null)
if [ "$CNF_PERMS" != "600" ] && [ "$CNF_PERMS" != "400" ]; then
    log "WARNING: $MY_CNF has permissions $CNF_PERMS (recommended 600). Running: chmod 600"
    chmod 600 "$MY_CNF"
fi

# Check mysqldump
if ! command -v mysqldump >/dev/null 2>&1; then
    log "ERROR: mysqldump command not found!"
    exit 1
fi

# Check mysql client
if ! command -v mysql >/dev/null 2>&1; then
    log "ERROR: mysql command not found!"
    exit 1
fi

# Preflight: test login before dumping (would catch ERROR 1045)
if ! mysql --defaults-extra-file="$MY_CNF" -e "SELECT 1" >/dev/null 2>>"$LOG_FILE"; then
    log "ERROR: Connection to MySQL failed. Check $MY_CNF (user/password/host)."
    log "Tip: try manually -> mysql --defaults-extra-file=$MY_CNF"
    exit 1
fi

# -----------------------------------------------------------------------------
# Helper: check whether database name is in EXCLUDE_DBS list
# -----------------------------------------------------------------------------
is_excluded() {
    local NAME="$1"
    while IFS= read -r EX; do
        EX="${EX%%#*}"
        EX="$(echo "$EX" | xargs)"
        [ -z "$EX" ] && continue
        if [ "$EX" = "$NAME" ]; then
            return 0
        fi
    done <<< "$EXCLUDE_DBS"
    return 1
}

# Get databases
DATABASES=$(mysql --defaults-extra-file="$MY_CNF" -e "SHOW DATABASES;" 2>>"$LOG_FILE" | tail -n +2)

if [ -z "$DATABASES" ]; then
    log "ERROR: Could not retrieve database list (empty output)."
    exit 1
fi

# -----------------------------------------------------------------------------
# Backup each database
# -----------------------------------------------------------------------------
FAILED=0
SUCCEEDED=0
SKIPPED=0
FAILED_DBS=""

for DB in $DATABASES; do
    if is_excluded "$DB"; then
        log "Skipping excluded database: $DB"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    BACKUP_FILE="$TODAYS_BACKUP_DIR/${DB}.sql.gz"
    log "Backing up $DB -> $(basename "$BACKUP_FILE")..."

    if mysqldump --defaults-extra-file="$MY_CNF" \
            --single-transaction --quick --routines --triggers --events \
            "$DB" 2>>"$LOG_FILE" | gzip -9 > "$BACKUP_FILE"; then
        # verify the file is not empty (pipefail + this check)
        if [ -s "$BACKUP_FILE" ]; then
            log "OK: $DB saved ($(du -h "$BACKUP_FILE" | cut -f1))"
            SUCCEEDED=$((SUCCEEDED+1))
        else
            log "ERROR: $DB – output file is empty"
            rm -f "$BACKUP_FILE"
            FAILED=$((FAILED+1))
            FAILED_DBS="$FAILED_DBS $DB"
        fi
    else
        log "ERROR: Failed to backup $DB"
        rm -f "$BACKUP_FILE"
        FAILED=$((FAILED+1))
        FAILED_DBS="$FAILED_DBS $DB"
    fi
done

# If today's folder is empty, remove it
if [ -z "$(ls -A "$TODAYS_BACKUP_DIR" 2>/dev/null)" ]; then
    rmdir "$TODAYS_BACKUP_DIR" 2>/dev/null
fi

# -----------------------------------------------------------------------------
# Backup rotation – only when we have at least one successful new dump
# -----------------------------------------------------------------------------
if [ "$SUCCEEDED" -gt 0 ]; then
    log "Rotation: keeping last $RETENTION_COUNT backups..."
    BACKUP_DIRS=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
        -printf '%T@ %p\n' | sort -rn | awk '{print $2}')

    INDEX=0
    while IFS= read -r DIR; do
        [ -z "$DIR" ] && continue
        INDEX=$((INDEX+1))
        if [ "$INDEX" -gt "$RETENTION_COUNT" ]; then
            log "Removing old backup: $DIR"
            rm -rf "$DIR"
        fi
    done <<< "$BACKUP_DIRS"
else
    log "WARNING: no successful backup – skipping rotation."
fi

# -----------------------------------------------------------------------------
# Log rotation – always
# -----------------------------------------------------------------------------
LOG_FILES=$(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type f -name 'backup_*.log' \
    -printf '%T@ %p\n' | sort -rn | awk '{print $2}')

LOG_INDEX=0
while IFS= read -r LF; do
    [ -z "$LF" ] && continue
    LOG_INDEX=$((LOG_INDEX+1))
    if [ "$LOG_INDEX" -gt "$LOG_RETENTION" ]; then
        log "Removing old log: $LF"
        rm -f "$LF"
    fi
done <<< "$LOG_FILES"

if [ "$FAILED" -gt 0 ]; then
    log "Backup finished WITH ERRORS. OK: $SUCCEEDED, FAIL: $FAILED, SKIP: $SKIPPED. Saved in $TODAYS_BACKUP_DIR"
    log "Failed databases:$FAILED_DBS"
    exit 1
fi

log "Backup finished. Saved in $TODAYS_BACKUP_DIR (databases: $SUCCEEDED, skipped: $SKIPPED)"
exit 0
