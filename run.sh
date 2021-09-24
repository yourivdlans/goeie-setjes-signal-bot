#!/bin/bash

dbus_address=`dbus-daemon --config-file=/usr/share/dbus-1/session.conf --print-address --fork`

export DBUS_SESSION_BUS_ADDRESS=$dbus_address

signal-cli -u $SIGNAL_USER_ACCOUNT --trust-new-identities=always daemon &

echo "Starting signal bot with $SIGNAL_USER_ACCOUNT..."

ruby lib/main.rb
