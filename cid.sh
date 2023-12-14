#!/bin/bash

TOOLKIT="ecid/toolkit"

if [ "$1" == "--noupdate" ]; then
    shift
    noupdate=1
fi

if [ "$noupdate" == "" ]; then
    echo "Making sure cidtoolkit is up to date ..."
    if ! docker pull "$TOOLKIT"; then
        echo "Warning: Could not update toolkit."
    fi
fi

docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/src/" "$TOOLKIT" "$@"
