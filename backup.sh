#!/bin/bash

[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
# If provided, take password from file
[ -z "${MYSQL_PASS_FILE}" ] || { MYSQL_PASS=$(head -1 "${MYSQL_PASS_FILE}"); }
# Alternatively, take it from env var
[ -z "${MYSQL_PASS:=$MYSQL_PASSWORD}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }
[ -z "${GZIP_LEVEL}" ] && { GZIP_LEVEL=6; }

DATE=$(date +%Y%m%d%H%M)
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"
DATABASES=${MYSQL_DATABASE:-${MYSQL_DB:-$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)}}
for db in ${DATABASES}
do
  if  [[ "$db" != "information_schema" ]] \
      && [[ "$db" != "performance_schema" ]] \
      && [[ "$db" != "mysql" ]] \
      && [[ "$db" != "sys" ]] \
      && [[ "$db" != _* ]]
  then
    echo "==> Dumping database: $db"
    FILENAME=/backup/$DATE.$db.sql
    LATEST=/backup/latest.$db.sql.gz
    if mysqldump --single-transaction -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db" $MYSQLDUMP_OPTS > "$FILENAME"
    then
      gzip "-$GZIP_LEVEL" -f "$FILENAME"
      echo "==> Creating symlink to latest backup: $(basename "$FILENAME".gz)"
      rm "$LATEST" 2> /dev/null
      cd /backup || exit && ln -s "$(basename "$FILENAME".gz)" "$(basename "$LATEST")"
      if [ -n "$MAX_BACKUPS" ]
      then
        while [ "$(find /backup -maxdepth 1 -name "*.$db.sql.gz" -type f | wc -l)" -gt "$MAX_BACKUPS" ]
        do
          TARGET=$(find /backup -maxdepth 1 -name "*.$db.sql.gz" -type f | sort | head -n 1)
          echo "==> Max number of backups ($MAX_BACKUPS) reached. Deleting ${TARGET} ..."
          rm -rf "${TARGET}"
          echo "==> Backup ${TARGET} deleted"
        done
      fi
    else
      rm -rf "$FILENAME"
    fi
  fi
done
echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
