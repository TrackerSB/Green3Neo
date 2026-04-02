use diesel::Connection;

use crate::connection::DbConnection;

// Create a diesel based connection from a test database connection
pub async fn to_diesel_connection(sqlx_connection: &mut sqlx::PgConnection) -> DbConnection {
    let test_db_name: String = sqlx::query_scalar!("SELECT current_database()")
        .fetch_one(sqlx_connection)
        .await
        .expect("Querying current database name failed")
        .expect("Result database name is empty");

    let configured_url = std::env::var("DATABASE_URL").expect("Could not determine database URL");

    let test_db_url = configured_url
        .split_at(
            configured_url
                .rfind("/")
                .expect("Could not find slash separating DB address from DB name")
                + 1,
        )
        .0
        .to_owned()
        + &test_db_name;

    DbConnection::PostgreSql(
        diesel::PgConnection::establish(&test_db_url).expect("Could not establish connection"),
    )
}
