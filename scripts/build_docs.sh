#!/bin/sh

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";


cp -f $PROJECT_DIR/CHANGELOG.md $PROJECT_DIR/docs/release-notes.md;
mkdocs build -d $PROJECT_DIR/public
