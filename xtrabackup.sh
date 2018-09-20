#!/bin/bash
 
backup_path="/bs-db-backups"
 
yesterday=$(date +"%m-%d-%y" --date="1 days ago")
yesterday_backup_path=$backup_path/$yesterday
 
date=$(date +"%m-%d-%y")
todays_backup_path=$backup_path/$date
 
#Check to make sure this node is not a Galera master before proceeding
state=$(cat /var/log/keepalived.log | tail -1 | grep -Eo '(Backup|Master)')
#If the backup folder exists and has contents, we'll have a non-empty variable. If it is empty, it'll be True in the below if statement
backup_not_done=$(ls -la $todays_backup_path 2>/dev/null)
 
if [[ "$state" == "Backup" && -z "$($backup_not_done)" ]]
then
    echo "Backup not performed today, proceeding with MySQL backup."
    mkdir -p $backup_path/$date
    innobackupex $todays_backup_path --no-timestamp
    innobackupex --apply-log $todays_backup_path
else
    echo "Backup already performed or we're a Galera Master! Backups will NOT run on this node."
fi
 
if [[ -a "$yesterday_backup_path" ]]
then
    # Tar yesterday's backup with pigz. Pigz is multi-threaded gzip which is useful for humongous backups
    # Only tar yesterday's backup because today's backup is more likely to be needed for a critical revert.
    tar -cf - $yesterday_backup_path | pigz --fast -p 6 > $backup_path/$yesterday.tar.gz && rm -rf $yesterday_backup_path
    echo "Yesterday's backup compressed successfully"
else
    echo "Previous backup not found, not compressing"
fi
