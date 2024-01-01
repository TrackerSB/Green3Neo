import psycopg2
from dotenv import load_dotenv
from os import getenv

def _get_existing_tables(connection):
    try:
        cursor = connection.cursor()

        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
                AND table_type = 'BASE_TABLE';
        """)

        return [record[0] for record in cursor.fetchall()]
    except Exception as ex:
        print("Requesting existing tables failed")
        raise ex
    finally:
        cursor.close()


def _delete_tables(connection):
    try:
        cursor = connection.cursor()
        
        tables_to_delete = _get_existing_tables(connection)
        for table in tables_to_delete:
            cursor.execute(f"DROP TABLE IF EXISTS {table} CASCADE;")

        connection.commit()
    except Exception as ex:
        print("Dropping database tables failed")
        raise ex
    finally:
        cursor.close()

def _main()->None:
    load_dotenv()

    db_config = {
        "host": getenv("DB_HOST"),
        "port": getenv("DB_PORT"),
        "database": getenv("DB_NAME"),
        "user": getenv("DB_USER"),
        "password": getenv("DB_PASSWORD"),
    }

    try:
        connection = psycopg2.connect(**db_config)

        _delete_tables(connection)
    except Exception as ex:
        print(f"Deletion of database tables failed: {ex}")
    finally:
        connection.close()

if __name__=="__main__":
    _main()