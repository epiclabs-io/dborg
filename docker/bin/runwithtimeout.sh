#!/bin/bash

run_with_timeout() {
    # First parameter is the timeout
    local timeout=$1

    # Remove the first parameter (timeout) from the list
    shift

    # Run the command in the background
    "$@" &
    local command_pid=$!

    # Wait for the command to finish or timeout
    local elapsed=0
    while kill -0 $command_pid 2>/dev/null; do
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "Command timed out. Killing the process."
            kill -9 $command_pid
            return 1
        fi
        sleep 1
        ((elapsed++))
    done

    # Wait for the process to completely finish and get the exit status
    wait $command_pid
    local exit_status=$?

    return $exit_status
}

run_with_timeout "$@"
