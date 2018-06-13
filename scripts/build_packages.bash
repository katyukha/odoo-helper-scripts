#!/bin/env bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";

BUILD_DIR="$PROJECT_DIR/build";


mkdir -p $BUILD_DIR;
rm -f $BUILD_DIR/*;

deb_version=${CI_COMMIT_REF_NAME:-$($PROJECT_DIR/bin/odoo-helper exec echo "\$ODOO_HELPER_VERSION" 2>/dev/null)};

deb_depends="git wget lsb-release procps
    python-setuptools libevent-dev g++ libpq-dev
    python-dev python3-dev libjpeg-dev libyaml-dev 
    libfreetype6-dev zlib1g-dev libxml2-dev libxslt-dev bzip2 
    libsasl2-dev libldap2-dev libssl-dev libffi-dev";
deb_depends_opt=$(for dep in $deb_depends; do echo "--depends $dep"; done);

fpm -s dir -t deb -p $BUILD_DIR/ \
    --name odoo-helper-scripts \
    --description "Just a simple collection of odoo scripts. mostly to ease addons development process (allows to install and manage odoo instances in virtualenv)" \
    --config-files /etc/odoo-helper.conf \
    --vendor "Dmytro Katyukha" \
    --maintainer "Dmytro Katyukha" \
    --url "https://katyukha.gitlab.io/odoo-helper-scripts/" \
    --category "utils" \
    --iteration ubuntu\
    --architecture all \
    --version $deb_version  \
    $deb_depends_opt \
    --license "Mozilla Public License, v. 2.0" \
    --deb-recommends expect-dev \
    --deb-recommends tcl8.6 \
    $PROJECT_DIR/bin/=/usr/bin/ \
    $PROJECT_DIR/lib/=/opt/odoo-helper-scripts/lib/ \
    $PROJECT_DIR/CHANGELOG.md=/opt/odoo-helper-scripts/ \
    $PROJECT_DIR/defaults/odoo-helper.conf=/etc/
    
