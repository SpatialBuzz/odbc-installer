#!/bin/bash -eu
source functions.sh

FILE_SQL="${1}"

get_customer_name
get_athena_credentials

convert_sql_to_spatialite

echo
info "Created: ${FILE_VRT}"
info "Created: ${FILE_SQLITE}"