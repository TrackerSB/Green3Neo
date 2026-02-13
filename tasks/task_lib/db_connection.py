import psycopg2
from psycopg2._psycopg import connection
from dotenv import load_dotenv
from os import getenv
from typing import Dict, List, Tuple, Any, Optional
from pathlib import Path


def read_credentials() -> Dict[str, str]:
    load_dotenv()

    return {
        "host": getenv("BUILD_DB_HOST"),
        "port": getenv("BUILD_DB_PORT"),
        "database": getenv("BUILD_DB_NAME"),
        "user": getenv("BUILD_DB_USER"),
        "password": getenv("BUILD_DB_PASSWORD"),
    }


def create_connection() -> connection:
    return psycopg2.connect(**read_credentials())


def execute_query(
    connection: connection, query: str
) -> Optional[List[Tuple[Any, ...]]]:
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


def execute_script(connection: connection, script: Path):
    with script.open() as file:
        script_content = file.read()
        execute_query(connection, script_content)
