#!/bin/bash -ue

# Copyright © 2021 - Ookla, LLC. All Rights Reserved.

source functions.sh

check_user_odbc_settings
get_customer_name
get_credentials
install_xcode
install_homebrew
install_athena_driver
install_iodbc_admin
install_dsn
test_odbc
launch_qgis
launch_odbc_admin

info "Installation complete"