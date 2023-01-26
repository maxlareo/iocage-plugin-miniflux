#!/bin/sh

set -eu

# Enable the necessary services
sysrc -f /etc/rc.conf postgresql_enable="YES"
sysrc -f /etc/rc.conf postgresql_initdb_flags="--encoding=utf-8 --lc-collate=C --auth=trust"
sysrc -f /etc/rc.conf miniflux_enable="YES"

# Start the service
service postgresql initdb
service postgresql start

DBUSER="miniflux"
DB="miniflux"
MFUSER="admin"

# Save the config values
echo "$DB" > /root/dbname
echo "$DBUSER" > /root/dbuser
echo "$MFUSER" > /root/mfuser
export LC_ALL=C
openssl rand --hex 8 > /root/dbpassword
openssl rand --hex 8 > /root/mfpassword
DBPASS=$(cat /root/dbpassword)
MFPASS=$(cat /root/mfpassword)

su -l postgres -c "createuser ${DBUSER}"
su -l postgres -c "createdb -O ${DBUSER} ${DB}"
su -l postgres -c "psql -c \"ALTER USER ${DBUSER} WITH PASSWORD '${DBPASS}';\""
su -l postgres -c "psql miniflux -c 'create extension hstore'"

cat > /usr/local/etc/miniflux.env << EOF
# See https://miniflux.app/docs/configuration.html

LISTEN_ADDR=0.0.0.0:8080
DATABASE_URL=user=${DBUSER} password=${DBPASS} dbname=${DB} sslmode=disable
RUN_MIGRATIONS=1
EOF

miniflux -c /usr/local/etc/miniflux.env -migrate

export ADMIN_USERNAME="${MFUSER}"
export ADMIN_PASSWORD="${MFPASS}"

miniflux -c /usr/local/etc/miniflux.env -create-admin

service miniflux start

cat > /root/PLUGIN_INFO << EOF
Database Name: $DB
Database User: $DBUSER
Database Password: $DBPASS
Miniflux Admin User: $MFUSER
Miniflux Admin Password: $MFPASS
EOF
