#!/bin/bash

host=$(hostname)
base=server.js
script=$APP_ROOT/src/dataNode/$host/$base

line=$(forever list 2>/dev/null | grep "$script")
if [ -z "$line" ]; then
  echo "ERROR: server $host is already stopped." >&2
  exit 0
fi

forever stop "$script"
exit $?
