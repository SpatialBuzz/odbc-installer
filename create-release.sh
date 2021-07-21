#!/bin/bash -eu

DATE_STAMP=$(date -u +'%Y%m%d')
ZIP_FOLDER=$(pwd)/release/
ZIP_FILE=${ZIP_FOLDER}/odbc_installer_${DATE_STAMP}.zip

mkdir -p ${ZIP_FOLDER}

zip ${ZIP_FILE} functions.sh install.sh license.sh README.md test-odbc.sh