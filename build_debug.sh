#!/bin/bash

SRC_DIR=$(dirname ${BASH_SOURCE[0]})
if [ ! -e $SRC_DIR/node_modules/.bin/elm ]; then
    echo missing elm in $SRC_DIR
    exit -1
fi
export PATH=$SRC_DIR/node_modules/.bin:$PATH
elm make src/Main.elm --output elm.js
