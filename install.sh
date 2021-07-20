#!/bin/bash -ue

# Copyright © 2021 - Ookla, LLC. All Rights Reserved.

source functions.sh

check_user_odbc_settings
get_customer_name
get_sudo_credentials
install_xcode
install_homebrew
install_athena_driver
install_iodbc_admin
install_dsn

info "Installation complete - now run ./test-odbc.sh to verify installation"
