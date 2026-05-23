# Linux Database Backup Script

Simple and safe MySQL / MariaDB backup system for Linux servers.
Backups are compressed per database, separated by timestamp, and old backups
and logs are automatically rotated.

> **Out of the box** the script automatically detects all your databases and
> dumps each one into its own `.sql.gz` file – no configuration needed for the
> typical case, just fill in your MySQL password.

---

## 📥 Installation

### 1. Download the file

Easiest way – download the script directly to the server:

```
mkdir -p /opt/linux-database-backup
cd /opt/linux-database-backup
wget https://github.com/Yamiru/linux-database-backup/blob/main/backup_mysql.sh
wget https://raw.githubusercontent.com/Yamiru/linux-database-backup/main/.my.cnf.example
```

Or download the whole repository as a ZIP and upload it to:

```
/opt/linux-database-backup/
```

### 2. Make the script executable

```
chmod +x /opt/linux-database-backup/backup_mysql.sh
```

### 3. Configure MySQL credentials

Rename `.my.cnf.example` to `.my.cnf` and insert your MySQL password:

```
[client]
user=root
password=YOUR_PASSWORD_HERE
host=localhost
```

Then secure it:

```
chmod 600 /opt/linux-database-backup/.my.cnf
```

### 4. (Optional) Secure the folder

```
chown -R root:root /opt/linux-database-backup
chmod 700 /opt/linux-database-backup
```

### 5. Run it

```
/opt/linux-database-backup/backup_mysql.sh
```

That's it – with default settings the script will:

- detect all your databases automatically
- dump each one into its own `.sql.gz` archive (gzip -9)
- write a timestamped log file
- keep the last 5 backups and the last 5 logs

---

## 📦 How It Works

- Automatically detects all MySQL / MariaDB databases

- Skips system databases (`mysql`, `sys`, `information_schema`,
  `performance_schema`, `test`) – the exclude list is configurable in the script

- Each database is dumped into its own `.sql.gz` using `gzip -9` compression

- Stores each run in a timestamped folder inside `BACKUP_DIR`:

  ```
  $BACKUP_DIR/YYYY-MM-DD_HHMMSS/
  ```

- Writes a separate log file per run into `LOG_DIR`:

  ```
  $LOG_DIR/backup_YYYY-MM-DD_HHMMSS.log
  ```

- Keeps the last **5 backups** and the last **5 log files**, older ones are deleted

- Old backups are only deleted **after** a successful new run – your last good
  copy is never wiped by a failed run

---

## 🛡 Safety Features

- **Preflight check** – tests MySQL login with `SELECT 1` before dumping, so
  wrong credentials are caught early (no half-empty backup folder)
- **Disk space warning** – logs a warning if free space on `BACKUP_DIR` drops
  below the configured threshold
- **Permission auto-fix** – if `.my.cnf` has wrong permissions, the script
  fixes them to `600` automatically (mysql client otherwise ignores the file)
- **Empty-file detection** – if a dump produces an empty `.sql.gz` (broken
  pipe, killed process), it is treated as failed and removed
- **Failed database list** – the final log line names exactly which databases
  failed, not just the count

---

## ⚙ Configuration

At the top of `backup_mysql.sh`:

```
# Storage paths (can point to different folders / different disks)
BACKUP_DIR="/opt/linux-database-backup/backups"
LOG_DIR="/opt/linux-database-backup/logs"

# MySQL credentials file
MY_CNF="/opt/linux-database-backup/.my.cnf"

# Rotation settings
RETENTION_COUNT=5   # number of backup folders to keep
LOG_RETENTION=5     # number of log files to keep

# Safety settings
MIN_FREE_MB=500   # warn if free space drops below this; 0 = disable

# Excluded databases
EXCLUDE_DBS=$(cat <<'EOF'
information_schema
performance_schema
mysql
sys
test
EOF
)
```

`BACKUP_DIR` and `LOG_DIR` are independent – you can point them to completely
different locations (for example, backups on a mounted external disk, logs on
the system disk).

---

## ⏱ CRON Setup

Open crontab:

```
crontab -e
```

Add this line to run a backup every day at 02:00:

```
0 2 * * * /opt/linux-database-backup/backup_mysql.sh >/dev/null 2>&1
```

Logs are written by the script itself into `LOG_DIR`.

> The `>/dev/null 2>&1` part discards cron output, because the script already
> maintains its own log files. If you want email notifications on errors,
> remove the redirect and set `MAILTO=` at the top of crontab.

---

## 📁 Restore Example

List archives in a backup folder:

```
ls -lh /opt/linux-database-backup/backups/2026-05-23_020000/
```

Restore a single database:

```
gunzip < /opt/linux-database-backup/backups/2026-05-23_020000/mydatabase.sql.gz \
    | mysql mydatabase
```

Restore into a freshly created database:

```
mysql -e "CREATE DATABASE mydatabase CHARACTER SET utf8mb4;"
gunzip < /opt/linux-database-backup/backups/2026-05-23_020000/mydatabase.sql.gz \
    | mysql mydatabase
```

---

## ✔ Requirements

- Linux server
- `bash`, `mysql`, `mysqldump`, `gzip`, `find`
- MySQL or MariaDB with a user that has at least
  `SELECT`, `SHOW VIEW`, `LOCK TABLES`, `EVENT`, `TRIGGER` privileges
  (or simply `root` for full coverage)

---

## 👍 Notes

The `backups/` and `logs/` folders are git-ignored.

This project uses `.my.cnf.example`. The real `.my.cnf` is ignored by Git for
security reasons.

---

## 📜 License

This project is licensed under the MIT License – see the [LICENSE](https://github.com/Yamiru/linux-database-backup/blob/main/LICENSE) file for details.

---

If you find this project useful, please ⭐ star it on GitHub!

Created with ❤️ by [Yamiru](https://yamiru.com/)
