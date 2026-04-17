from task_lib import db_connection
from pathlib import Path

from os import path
import sys


def _create_tables(connection: db_connection.DbConnection) -> None:
    script_folder = path.dirname(path.realpath(__file__))
    db_connection.execute_script(
        connection, Path(script_folder + "/resources/dummyData.sql")
    )


def _main() -> None:
    connection = db_connection.create_connection()

    try:
        _create_tables(connection)
    except Exception as ex:
        print(f"Creation of database tables failed: {ex}")
        sys.exit(1)
    finally:
        connection.close()


if __name__ == "__main__":
    _main()
