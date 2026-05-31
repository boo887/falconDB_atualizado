#!/bin/bash

host=$(hostname)
base=server.js
script=$APP_ROOT/src/dataNode/$host/$base

line=$(forever list 2>/dev/null | grep "$script")
if [ -n "$line" ]; then
  echo "ERROR: server $host is already running." >&2
  exit 10
fi

forever-start "$script"
exit $?
