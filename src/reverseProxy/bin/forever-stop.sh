#!/bin/bash

base=server.js
TMPe=/tmp/frv-stop-$$.err
TMPo=/tmp/frv-stop-$$.out
trap "/bin/rm -f $TMPe $TMPo" 0 1 2 3 4 5

line=$(ps -elf | grep "forever/bin/monitor $base" | grep -v grep)
#echo line: \"$line\"

if [ -z "$line" ]; then
  echo "ERROR: server $server_type in host $hostname is already stoped." >&2
  exit 0
fi

cd $APP_ROOT/src/$server_type
forever stop $base >$TMPo 2>$TMPe
r=$?
test $r -ne 0 && cat $TMPe

exit $r
