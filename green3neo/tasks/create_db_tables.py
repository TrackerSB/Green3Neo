from psycopg2._psycopg import connection
from task_lib import db_connection


def _create_tables(connection: connection) -> None:
    db_connection.execute_query(
        connection,
        """
        CREATE TABLE IF NOT EXISTS Member(
            membershipId integer NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
            prename varchar(255) NOT NULL,
            lastname varchar(255) NOT NULL,
            title varchar(15) NOT NULL,
            isMale boolean NOT NULL,
            birthday date NOT NULL,
            street varchar(255) NOT NULL,
            houseNumber varchar(255) NOT NULL,
            zipCode varchar(255) NOT NULL,
            city varchar(255) NOT NULL,
            isActive boolean NOT NULL,
            isFoundingMember boolean NOT NULL DEFAULT FALSE,
            isHonoraryMember boolean NOT NULL DEFAULT FALSE,
            isContributionfree boolean NOT NULL DEFAULT FALSE,
            contributorSinceYear int DEFAULT NULL,
            joinDate date NOT NULL DEFAULT CURRENT_DATE,
            exitDate date DEFAULT NULL,
            phoneNumber varchar(255) DEFAULT NULL,
            mobileNumber varchar(255) DEFAULT NULL,
            email varchar(255) DEFAULT NULL,
            accountHolderPrename varchar(255) DEFAULT NULL,
            accountHolderLastname varchar(255) DEFAULT NULL,
            iban varchar(255) NOT NULL,
            bic varchar(255) NOT NULL,
            mandateSince date NOT NULL DEFAULT CURRENT_DATE,
            honoraryYears integer[] DEFAULT '{}',
            contributionHonoraryYears integer[] DEFAULT '{}',
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