#!/bin/bash

export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/ruby-dbus"
DBUS_SESSION_BUS_PID=$(dbus-daemon --config-file=/usr/share/dbus-1/session.conf --fork --print-pid --address="$DBUS_SESSION_BUS_ADDRESS")

signal-cli -u $SIGNAL_USER_ACCOUNT --trust-new-identities=always daemon --dbus &

echo "Starting signal bot with $SIGNAL_USER_ACCOUNT..."

ruby lib/main.rb
