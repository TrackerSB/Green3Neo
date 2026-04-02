import psycopg2
from psycopg2._psycopg import connection as PgConnection
from os import getenv
from typing import Dict, List, Tuple, Any, Optional, Union
from pathlib import Path
from mysql.connector import MySQLConnection, connect

type DbConnection = Union[PgConnection, MySQLConnection]


def read_env_config() -> Dict[str, str]:
    protocol = getenv("BUILD_DB_PROTOCOL")

    assert protocol is not None

    return {
        "protocol": protocol,
        "host": getenv("BUILD_DB_HOST"),
        "port": getenv("BUILD_DB_PORT"),
        "database": getenv("BUILD_DB_NAME"),
        "user": getenv("BUILD_DB_USER"),
        "password": getenv("BUILD_DB_PASSWORD"),
    }


def create_connection() -> DbConnection:
    env_config = read_env_config()
    if env_config["protocol"] == "postgres":
        return psycopg2.connect(
            host=env_config["host"],
            port=env_config["port"],
            database=env_config["database"],
            user=env_config["user"],
            password=env_config["password"],
        )
    elif env_config["protocol"] == "mysql":
        return connect(
            host=env_config["host"],
            port=env_config["port"],
            database=env_config["database"],
            user=env_config["user"],
            password=env_config["password"],
        )
    else:
        raise RuntimeError(f"Unsupported DB protocol {env_config['protocol']}")


def execute_query(
    connection: DbConnection, query: str
) -> Optional[List[Tuple[Any, ...]]]:
    if isinstance(connection, PgConnection):
        try:
            cursor = connection.cursor()

            cursor.execute(query)

            if cursor.description is None:
                query_result = None
            else:
                query_result = cursor.fetchall()

            connection.commit()

            return query_result
        finally:
            cursor.close()
    elif isinstance(connection, MySQLConnection):
        try:
            cursor = connection.cursor()

            cursor.execute(query)

            print(f"MySQL: Cursor description {cursor.description}")
            if cursor.description is None:
                query_result = None
            else:
                query_result = cursor.fetchall()

            connection.commit()

            return query_result
        finally:
            cursor.close()
    else:
        raise RuntimeError("Unsupported DB backend")


def execute_script(connection: DbConnection, script: Path):
    with script.open() as file:
        script_content = file.read()
        execute_query(connection, script_content)
