#!/bin/zsh

source ./subtasks/activateVenv.zsh

# python ./delete_db_tables.py
# python ./create_db_tables.py
python ./populate_db_tables.py

source ./subtasks/deactivateVenv.zsh