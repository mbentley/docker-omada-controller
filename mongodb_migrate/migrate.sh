#!/bin/bash

catch_error() {
  echo "ERROR: Unexpected failure!"
  exit 1
}

### upgrade to 4.0
echo -e "\nINFO: Starting migration to 4.0..."

# run repair on db to upgrade
/tmp/mongod-4.0.28 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal --repair || catch_error

# start db
/tmp/mongod-4.0.28 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal &

# set compatibility version to 4.0
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "4.0" } )' | /tmp/mongo-4.0.28
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 4.0 complete!\n"


### upgrade to 4.2
if [ "$(uname -m)" = "aarch64" ]
then
  echo "INFO: upgrading from libcurl3 to libcurl4"
  #apt-get update
  #apt-get install -y libcurl4
  dpkg -i /libcurl4_7.58.0-2ubuntu3.24_arm64.deb
fi

echo -e "\nINFO: Starting migration to 4.2..."

# run repair on db to upgrade
/tmp/mongod-4.2.23 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal --repair || catch_error

# start db
/tmp/mongod-4.2.23 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal &

# set compatibility version to 4.2
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "4.2" } )' | /tmp/mongo-4.2.23
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 4.2 complete!\n"


### upgrade to 4.4
echo -e "\nINFO: Starting migration to 4.4..."

# run repair on db to upgrade
/tmp/mongod-4.4.18 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal --repair || catch_error

# # start db
/tmp/mongod-4.4.18 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal &

# set compatibility version to 4.4
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "4.4" } )' | /tmp/mongo-4.4.18
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 4.4 complete!\n"


### upgrade to 5.0.27
echo -e "\nINFO: Starting migration to 5.0.27..."

# run repair on db to upgrade
/tmp/mongod-5.0.27 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal --repair || catch_error

# # start db
/tmp/mongod-5.0.27 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal &

# set compatibility version to 5.0
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "5.0" } )' | /tmp/mongo-5.0.27
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 5.0.27 complete!\n"


### upgrade to 6.0.16
echo -e "\nINFO: Starting migration to 6.0.16..."

# run repair on db to upgrade
/tmp/mongod-6.0.16 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal --repair || catch_error

# # start db
/tmp/mongod-6.0.16 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --journal &

# set compatibility version to 5.0
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "6.0" } )' | /tmp/mongosh
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 6.0.16 complete!\n"


### upgrade to 7.x
echo -e "\nINFO: Starting migration to 7.0.12..."

# run repair on db to upgrade
/tmp/mongod-7.0.12 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 --repair || catch_error

# # start db
/tmp/mongod-7.0.12 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 &

# set compatibility version to 5.0
while ! echo 'db.adminCommand( { setFeatureCompatibilityVersion: "7.0", confirm: true } )' | /tmp/mongosh
do
  echo "Sleeping! MongoDB isn't running yet"
  sleep 1
done

# stop mongodb
kill -2 "$(cat ../data/mongo.pid)"

# wait for mongodb to stop
echo -n "INFO: Waiting for mongod to stop..."
while pgrep mongod > /dev/null
do
  echo -n "."
  sleep 1
done
echo "done"

# remove pidfile
rm ../data/mongo.pid

# migration complete
echo -e "\nINFO: Migration to 7.0.12 complete!\n"

# set ownership
echo -ne "\nINFO: Fixing ownership of database files..."
chown -R "$(stat -c "%u:%g" ../data)" ../data
echo "done"
