#!/bin/bash

IMAGENAME="$1"

pushd ./docker || exit 1

if ! docker build -t "$IMAGENAME" .; then
    echo "Error building image"
    popd || exit 1
    exit 1
fi

popd || exit 1
