#!/bin/sh
chmod 700 -R /var/lib/postgresql/12/main
chown -R postgres:postgres /var/lib/postgresql/12/main
if [ -z "$(ls -A /var/lib/postgresql/12/main)" ]; then
  su - postgres -c '/usr/lib/postgresql/12/bin/pg_ctl -D /usr/local/pgsql/data initdb -D /var/lib/postgresql/12/main'
fi

service postgresql start

if ! su - postgres -c 'psql -lqt | cut -d \| -f 1 | grep -qw logDB'; then
  su - postgres -c 'createdb logDB'
fi

sudo -u postgres 'psql' 'logDB' "-c ALTER USER postgres PASSWORD 'pass';"

filename="/app/experiments.txt"
while read line
do
  if [ "$line" != "" ] && ! sudo -u postgres 'psql' 'logDB' "-c SELECT to_regclass('public.$line');" | grep -q "$line"; then
    sudo -u postgres 'psql' 'logDB' "-c CREATE TABLE \"$line\"(worker TEXT, sequence INTEGER, batch TEXT,client_time BIGINT,details JSON, task TEXT, type TEXT, server_time BIGINT, PRIMARY KEY (worker, sequence));"
  fi
done < $filename
service rabbitmq-server start
sudo rabbitmq-plugins enable rabbitmq_management
sudo pm2-runtime start server.js

