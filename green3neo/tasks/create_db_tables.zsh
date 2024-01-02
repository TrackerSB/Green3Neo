#!/bin/zsh

source ./subtasks/activateVenv.zsh

python ./create_db_tables.py

source ./subtasks/deactivateVenv.zsh