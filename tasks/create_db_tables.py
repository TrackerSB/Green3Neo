from psycopg2._psycopg import connection
from task_lib import db_connection


def _create_tables(connection: connection) -> None:
    db_connection.execute_query(
        connection,
        # NOTE 2024-06-23 SHU: "date" is converted to "NaiveDate". FRB does not explicitly support NaiveDate hence
        # utilizing RustOpaque which hides the internal structure and is therefore unusable for table views
        # (See https://github.com/fzyzcjy/flutter_rust_bridge/issues/1833).
        """
        CREATE TABLE IF NOT EXISTS Member(
            membershipId integer NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
            prename varchar(255) NOT NULL,
            surname varchar(255) NOT NULL,
            title varchar(15) DEFAULT NULL,
            isMale boolean NOT NULL,
            -- birthday date NOT NULL,
            street varchar(255) NOT NULL,
            houseNumber varchar(255) NOT NULL,
            zipCode varchar(255) NOT NULL,
            city varchar(255) NOT NULL,
            isActive boolean NOT NULL,
            isFoundingMember boolean NOT NULL DEFAULT FALSE,
            isHonoraryMember boolean NOT NULL DEFAULT FALSE,
            isContributionfree boolean NOT NULL DEFAULT FALSE,
            contributorSinceYear int DEFAULT NULL,
            -- joinDate date NOT NULL DEFAULT CURRENT_DATE,
            -- exitDate date DEFAULT NULL,
            phoneNumber varchar(255) DEFAULT NULL,
            mobileNumber varchar(255) DEFAULT NULL,
            email varchar(255) DEFAULT NULL,
            accountHolderPrename varchar(255) DEFAULT NULL,
            accountHolderSurname varchar(255) DEFAULT NULL,
            iban varchar(255) NOT NULL,
            bic varchar(255) NOT NULL,
            -- mandateSince date NOT NULL DEFAULT CURRENT_DATE,
            honoraryYears integer[] DEFAULT '{}' check (array_position(honoraryYears, NULL) IS NULL),
            contributionHonoraryYears integer[] DEFAULT '{}' check (array_position(honoraryYears, NULL) IS NULL),
            hasGauEhrenzeichen boolean NOT NULL DEFAULT FALSE,
            isEhrenschriftführer boolean NOT NULL DEFAULT FALSE,
            isEhrenvorstand boolean NOT NULL DEFAULT FALSE,
            isMemberOfBoard boolean NOT NULL DEFAULT FALSE
        );
        """,
    )


def _main() -> None:
    connection = db_connection.create_connection()

    try:
        _create_tables(connection)
    except Exception as ex:
        print(f"Creation of database tables failed: {ex}")
    finally:
        connection.close()


if __name__ == "__main__":
    _main()