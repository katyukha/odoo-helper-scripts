#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=$(basename "$SCRIPT");
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";

set -e;

echo "Preparing docs..."
bash "$SCRIPT_DIR"/prepare_docs.bash
echo "Docs ready!"

echo "Building docs..."
mkdocs build -d $PROJECT_DIR/public
echo "Docs built!"
