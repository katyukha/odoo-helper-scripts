#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=$(basename "$SCRIPT");
SCRIPT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=$(pwd);
PROJECT_DIR="$(readlink -f $SCRIPT_DIR/..)";

set -e


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

echo -e "#### odoo-helper install pre-requirements\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install pre-requirements --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install sys-deps\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install sys-deps --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install py-deps\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install py-deps --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install py-tools\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install py-tools --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install js-tools\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install js-tools --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install bin-tools\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install bin-tools --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install wkhtmltopdf\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install wkhtmltopdf --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install postgres\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install postgres --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install reinstall-odoo\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install reinstall-odoo --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper install reinstall-venv\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper install reinstall-venv --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper addons\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons list\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons list --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons install\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons install --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons update\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons update --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons uninstall\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons uninstall --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons update-list\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons update-list --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons status\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons status --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons generate-requirements\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons generate-requirements --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons test-installed\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons test-installed --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons find-installed\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons find-installed --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper addons pull-updates\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper addons pull-updates --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper db\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper db --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper db create\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper db create --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper db drop\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper db drop --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper db exists\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper db exists --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper fetch\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper fetch --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper link\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper link --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper server\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper server --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper server run\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper server run --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper server start\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper server start --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper lint\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper lint --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper lint flake8\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper lint flake8 --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper lint style\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper lint style --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper test\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper test --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper odoo\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper odoo --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper odoo recompute\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper odoo recompute --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper tr\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper tr export\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr export --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper tr import\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr import --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper tr load\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr load --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper tr regenerate\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr regenerate --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper tr rate\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper tr rate --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper postgres\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper postgres --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper postgres user-create\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper postgres user-create --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper postgres speedify\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper postgres speedify --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper git\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper git --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper git changed-addons\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper git changed-addons --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper ci\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper ci --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper ci ensure-icons\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper ci ensure-icons --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper ci check-versions-git\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper ci check-versions-git --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper doc-utils\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper doc-utils --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "#### odoo-helper doc-utils addons-list\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper doc-utils addons-list --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;

echo -e "### odoo-helper system\n\n" >> $PROJECT_DIR/docs/command-reference.md;
echo -e "~~~text\n$(odoo-helper system --help)\n~~~\n\n" >> $PROJECT_DIR/docs/command-reference.md;
