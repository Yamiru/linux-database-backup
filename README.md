# MySQL Auto Backup Script

Simple and safe MySQL backup system for Linux servers.\
Backups are compressed, separated by day, and old backups are
automatically deleted.

------------------------------------------------------------------------

## 📥 Installation

### 1. Download the files

Download this folder (ZIP) and upload it to:

    /opt/backup/

### 2. Make the script executable

    chmod +x /opt/backup/backup_mysql.sh

### 3. Configure MySQL credentials

Rename `.my.cnf.example` to `.my.cnf`

Edit `.my.cnf` and insert your MySQL password:

``` ini
[client]
user=root
password=YOUR_PASSWORD_HERE
host=localhost
```

Then secure it:

    chmod 600 /opt/backup/.my.cnf

------------------------------------------------------------------------

## 📦 How It Works

-   Automatically detects all MySQL databases\

-   Excludes system DBs (`mysql`, `sys`, etc.)

-   Uses gzip compression

-   Stores daily backups in folders:

        /opt/backup/YYYY-MM-DD/

-   Deletes backups older than **5 days**

------------------------------------------------------------------------

## ⏱ CRON Setup

Open crontab:

    crontab -e

Add this line to run backup every day at 02:00:

    0 2 * * * /opt/backup/backup_mysql.sh >> /var/log/backup_mysql.log 2>&1

Log file:

    /var/log/backup_mysql.log

------------------------------------------------------------------------

## 📁 Restore Example

    gunzip < 2025-01-20/mydatabase.sql.gz | mysql mydatabase

------------------------------------------------------------------------

## ✔ Requirements

-   Linux server
-   MySQL / MariaDB
-   mysqldump installed

------------------------------------------------------------------------

## 👍 Notes

This project uses `.my.cnf.example`.\
Real `.my.cnf` is **ignored by Git** for security reasons.
