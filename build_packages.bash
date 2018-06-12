#!/bin/env bash

mkdir -p build;
rm -f build/*;

deb_version=$(bin/odoo-helper exec echo "\$ODOO_HELPER_VERSION" 2>/dev/null);

deb_depends="git wget lsb-release procps
    python-setuptools libevent-dev g++ libpq-dev
    python-dev python3-dev libjpeg-dev libyaml-dev 
    libfreetype6-dev zlib1g-dev libxml2-dev libxslt-dev bzip2 
    libsasl2-dev libldap2-dev libssl-dev libffi-dev";
deb_depends_opt=$(for dep in $deb_depends; do echo "--depends $dep"; done);

fpm -s dir -t deb -p build/ \
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
    bin/=/usr/bin/ \
    lib/=/opt/odoo-helper-scripts/lib/ \
    CHANGELOG.md=/opt/odoo-helper-scripts/ \
    defaults/odoo-helper.conf=/etc/
    
