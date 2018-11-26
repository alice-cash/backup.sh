#backup.sh
backup.sh SERVER_NAME BACKUP_ROOT [options]
 Options:
        -x      : Compress Backups
        -m      : Make MySQL Backups
        -f      : Make Filesystem Backups
        -p path : Specify current backup option. Defaults to /YYY-MM-DD/
        -q      : Silent output, other than errors

 In order to function, SERVER_NAME needs to be a FQDN configured in ~/.ssh/config
 to allow for connections with no arguments such as for user, port or keyfile
 In order for MySQL backups to work, the remote server needs for ~/.my.cnf
 configured for the mysql and mysqldump commands to have access to the server

 Backups are stored under the following path:
 Files: BACKUP_ROOT/path/SERVER_NAME
 Compressed Files: BACKUP_ROOT/path/SERVER_NAME.tar.gz
 MySQL: BACKUP_ROOT/path/SERVER_NAME-MYSQL/database_name.sql
 Compressed MySQL: BACKUP_ROOT/path/SERVER_NAME-MYSQL/database_name.sql.gz

 Example cron usage:
 At midnight: Maintain a daily filesystem backup that overrides previous
 backups under the folder /backup/daily/server1.myhostname.com/:
 0 0 * * * /opt/backups/bin/backup.sh server1.myhostname.com /backup -fp daily

 At midnight: Maintain a compressed daily mysql under the folder
 /backup/YYY-MM-DD/server1.myhostname.com-MYSQL, replacing
 YYY-MM-DD with todays date:
 0 0 * * * /opt/backups/bin/backup.sh server1.myhostname.com /backup -fx

 At midnight every sunday morning, generate a daily compressed backup in
 the file /backup/YYY-MM-DD/server1.myhostname.com.tar.gz, replacing
 YYY-MM-DD with todays date:
 0 0 * * 0 /opt/backups/bin/backup.sh server1.myhostname.com /backup -fx
