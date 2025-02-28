#!/bin/bash

# Store process IDs
DBUS_PID=""
SIGNAL_CLI_PID=""
RUBY_PID=""

# Cleanup function to terminate all processes
# CTRL+C doesn't execute this function, so we need to use the signal
# Example: docker kill -s INT <container_id>
cleanup() {
    echo "Received shutdown signal, cleaning up..."

    # Kill Ruby process if running
    if [ -n "$RUBY_PID" ]; then
        echo "Stopping Ruby process..."
        kill -TERM "$RUBY_PID" 2>/dev/null
        wait "$RUBY_PID" 2>/dev/null
    fi

    # Kill signal-cli if running
    if [ -n "$SIGNAL_CLI_PID" ]; then
        echo "Stopping signal-cli daemon..."
        kill -TERM "$SIGNAL_CLI_PID" 2>/dev/null
        wait "$SIGNAL_CLI_PID" 2>/dev/null
    fi

    # Kill dbus-daemon if running
    if [ -n "$DBUS_PID" ]; then
        echo "Stopping dbus-daemon..."
        kill -TERM "$DBUS_PID" 2>/dev/null
    fi

    echo "Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/ruby-dbus"
DBUS_PID=$(dbus-daemon --config-file=/usr/share/dbus-1/session.conf --fork --print-pid --address="$DBUS_SESSION_BUS_ADDRESS")

exec signal-cli -u $SIGNAL_USER_ACCOUNT --trust-new-identities=always daemon --dbus &
SIGNAL_CLI_PID=$!

echo "Starting signal bot with $SIGNAL_USER_ACCOUNT..."

exec ruby lib/main.rb &
RUBY_PID=$!

echo "Ruby PID: $RUBY_PID"
echo "Signal CLI PID: $SIGNAL_CLI_PID"
echo "DBus PID: $DBUS_PID"

echo "All processes started. Waiting for signals..."

# Wait for any process to exit
wait -n

# After any process dies, clean up everything
cleanup
