#!/bin/bash

OSM_FILE=http://download.geofabrik.de/${MAP_REGION:-north-america}-latest.osm.pbf

mkdir -p /datasets/importdata
chown -R postgres /var/lib/postgresql/9.5/main

if [ ! -f /datasets/importdata/data.osm.pbf ]; then
  curl -L -f $OSM_FILE --create-dirs -o /datasets/importdata/data.osm.pbf
fi
if [ ! -f /datasets/importdata/country_osm_grid.sql.gz ]; then
  curl -L -f https://www.nominatim.org/data/country_grid.sql.gz --create-dirs -o /datasets/importdata/country_osm_grid.sql.gz 
fi

ln -s /datasets/importdata/country_osm_grid.sql.gz /app/src/data/country_osm_grid.sql.gz 

if [ ! -f /var/lib/postgresql/9.5/main/PG_VERSION ]; then
  sudo -u postgres /usr/lib/postgresql/9.5/bin/initdb -D /var/lib/postgresql/9.5/main
fi

service postgresql start
./wait-for-it.sh 127.0.0.1:5432 -t 100 -- sleep 2
if [ ! -f /intialsetup ]; then
  sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim
  sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
  sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim" && \
  sudo -u nominatim ./src/build/utils/setup.php --osm-file /datasets/importdata/data.osm.pbf --all --threads 4 && \
  touch /initialsetup
fi

/usr/sbin/apache2ctl -D FOREGROUND
