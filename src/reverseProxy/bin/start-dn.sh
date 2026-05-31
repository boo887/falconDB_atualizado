#!/bin/bash
# To start dn0-s0 server
ssh dn0-s0 ". ./.bashrc; /app/src/dataNode/bin/start.sh"
exit $?
