#!/bin/bash

# MySQL Backup Script
# Place this entire folder into /opt/backup/ 
# and configure .my.cnf based on .my.cnf.example.

BACKUP_DIR="/opt/backup"
MY_CNF="$BACKUP_DIR/.my.cnf"
RETENTION_DAYS=5
DATE=$(date +"%F")
LOGTIME=$(date +"%F %T")

TODAYS_BACKUP_DIR="$BACKUP_DIR/$DATE"
mkdir -p "$TODAYS_BACKUP_DIR"

echo "[$LOGTIME] --- Backup started ---"

# Check config
if [ ! -f "$MY_CNF" ]; then
    echo "[$LOGTIME] ERROR: Missing $MY_CNF"
    echo "Create it by copying .my.cnf.example -> .my.cnf"
    exit 1
fi

# Check mysqldump
if ! command -v mysqldump >/dev/null 2>&1; then
    echo "[$LOGTIME] ERROR: mysqldump command not found!"
    exit 1
fi

# Get databases
DATABASES=$(mysql --defaults-extra-file="$MY_CNF" -e "SHOW DATABASES;" | tail -n +2)

# Backup each database
for DB in $DATABASES; do
    case "$DB" in
        information_schema | performance_schema | mysql | sys | test)
            continue
        ;;
    esac

    BACKUP_FILE="$TODAYS_BACKUP_DIR/$DB.sql.gz"

    echo "[$LOGTIME] Backing up $DB..."
    if mysqldump --defaults-extra-file="$MY_CNF" "$DB" | gzip -9 > "$BACKUP_FILE"; then
        echo "[$LOGTIME] OK: $DB saved"
    else
        echo "[$LOGTIME] ERROR: Failed to backup $DB"
    fi
done

echo "[$LOGTIME] Cleaning backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "[$LOGTIME] Backup finished. Saved in $TODAYS_BACKUP_DIR"
