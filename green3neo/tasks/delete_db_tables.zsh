#!/bin/zsh

source ./subtasks/activateVenv.zsh

python ./delete_db_tables.py

source ./subtasks/deactivateVenv.zsh