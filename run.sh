#!/bin/bash

dbus_address=`dbus-daemon --config-file=/usr/share/dbus-1/session.conf --print-address --fork`

export DBUS_SESSION_BUS_ADDRESS=$dbus_address

signal-cli -u $SIGNAL_USER_ACCOUNT daemon &

echo "Waiting for signal-cli daemon to be ready..."

sleep 20

echo "Starting signal bot..."

ruby lib/main.rb
