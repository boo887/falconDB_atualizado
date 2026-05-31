#!/bin/bash

base=server.js

line=$(ps -elf | grep "forever/bin/monitor $base" | grep -v grep)
#echo line: \"$line\"

if [ ! -z "$line" ]; then
  echo "ERROR: server $server_type in host $hostname is already running." >&2
  exit 10
fi

forever-start  $APP_ROOT/src/$server_type/$base

exit $?
