import psycopg2
from psycopg2._psycopg import connection
from dotenv import load_dotenv
from os import getenv
from typing import Dict, List, Tuple, Any, Optional
from pathlib import Path


def read_credentials() -> Dict[str, str]:
    load_dotenv()

    return {
        "host": getenv("DB_HOST"),
        "port": getenv("DB_PORT"),
        "database": getenv("DB_NAME"),
        "user": getenv("DB_USER"),
        "password": getenv("DB_PASSWORD"),
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
