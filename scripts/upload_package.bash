#!/bin/env bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";

BUILD_DIR="$PROJECT_DIR/build";

deb_version="$1";

if [ -z "$deb_version" ]; then
    echo "Version is not specified";
    exit 1;
fi

# Push package to gitlab registry
package_name=odoo-helper-scripts_${deb_version}-ubuntu_all.deb
curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
    --upload-file "build/odoo-helper-scripts_${deb_version}-ubuntu_all.deb" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/odoo-helper-scripts/${deb_version}/yodoo-git-scanner_$deb_version-ubuntu_all.deb"

