#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";

# Copy changelog and contributing
cp -f $PROJECT_DIR/CHANGELOG.md $PROJECT_DIR/docs/release-notes.md;
cp -f $PROJECT_DIR/CONTRIBUTING.md $PROJECT_DIR/docs/contributing.md;

# Build command reference
echo -e "# Command reference\n\n" > $PROJECT_DIR/docs/command-reference.md;

echo -e "## odoo-install\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-install --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "## odoo-helper\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper install\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper addons\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper db\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper db --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper fetch\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper fetch --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper link\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper link --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper server\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper server --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper lint\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper lint --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper test\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper test --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper odoo\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper odoo --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper tr\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper postgres\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper postgres --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper git\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper git --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper ci\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper ci --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper doc-utils\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper doc-utils --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper system\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper system --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

mkdocs build -d $PROJECT_DIR/public
