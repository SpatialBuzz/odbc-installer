#!/bin/bash -ue

# Copyright © 2021 - Ookla, LLC. All Rights Reserved.

source functions.sh

get_customer_name
get_athena_credentials
test_odbc

info "Tests complete"
