#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=`pwd`;


cp -f $SCRIPT_DIR/CHANGELOG.md $SCRIPT_DIR/docs/release-notes.md;
mkdocs build -d $SCRIPT_DIR/public
