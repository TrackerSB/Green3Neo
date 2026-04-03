from task_lib import db_connection
import sys


def _create_tables(connection: db_connection.DbConnection) -> None:
    db_connection.execute_query(
        connection,
        # NOTE 2024-06-23: "date" is converted to "NaiveDate". FRB does not explicitly support NaiveDate hence
        # utilizing RustOpaque which hides the internal structure and is therefore unusable for table views
        # (See https://github.com/fzyzcjy/flutter_rust_bridge/issues/1833).
        # NOTE 2026-04-03: Since case sensitivity of identifiers (default behavior) between DB backends and the notation
        # for explicitly stating identifiers (default annotation) - to enforce case sensitivity - vary all table and
        # column names are chosen to be snake_case
        """
        CREATE TABLE IF NOT EXISTS member (
            membership_id integer NOT NULL PRIMARY KEY,
            prename varchar(255) NOT NULL,
            surname varchar(255) NOT NULL,
            title varchar(15) DEFAULT NULL,
            is_male boolean NOT NULL,
            -- birthday date NOT NULL,
            street varchar(255) NOT NULL,
            house_number varchar(255) NOT NULL,
            zip_code varchar(255) NOT NULL,
            city varchar(255) NOT NULL,
            is_active boolean NOT NULL,
            is_founding_member boolean NOT NULL DEFAULT FALSE,
            is_honorary_member boolean NOT NULL DEFAULT FALSE,
            is_contributionfree boolean NOT NULL DEFAULT FALSE,
            contributor_since_year int DEFAULT NULL,
            -- "join_date date NOT NULL DEFAULT CURRENT_DATE,
            -- "exit_date date DEFAULT NULL,
            phone_number varchar(255) DEFAULT NULL,
            mobile_number varchar(255) DEFAULT NULL,
            email varchar(255) DEFAULT NULL,
            accountholder_prename varchar(255) DEFAULT NULL,
            accountholder_surname varchar(255) DEFAULT NULL,
            iban varchar(255) NOT NULL,
            bic varchar(255) NOT NULL,
            -- mandate_since date NOT NULL DEFAULT CURRENT_DATE,
            has_gau_ehrenzeichen boolean NOT NULL DEFAULT FALSE,
            is_ehrenschriftführer boolean NOT NULL DEFAULT FALSE,
            is_ehrenvorstand boolean NOT NULL DEFAULT FALSE,
            is_member_of_board boolean NOT NULL DEFAULT FALSE
        );
        """,
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
