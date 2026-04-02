from task_lib import db_connection
from typing import List
import sys


def _get_existing_tables(connection: db_connection.DbConnection) -> List[str]:
    existing_tables = db_connection.execute_query(
        connection,
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE';
        """,
    )

    return [record[0] for record in existing_tables]


def _delete_tables(connection: db_connection.DbConnection) -> None:
    existing_tables = _get_existing_tables(connection)

    for table_name in existing_tables:
        print(f"Drop table {table_name}")
        db_connection.execute_query(
            connection, f"DROP TABLE IF EXISTS \"{table_name}\" CASCADE;"
        )


def _main() -> None:
    try:
        connection = db_connection.create_connection()

        _delete_tables(connection)
    except Exception as ex:
        print(f"Deletion of database tables failed: {ex}")
        sys.exit(1)
    finally:
        connection.close()


if __name__ == "__main__":
    _main()
