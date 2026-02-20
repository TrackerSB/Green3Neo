use diesel::Connection;
use speculoos::{assert_that, result::ResultAssertions};
use sqlx::Row;

use crate::{
    column_type_info::{ColumnTypeInfo, get_type_of_array},
    connection::DbConnection,
};

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

pub async fn get_all_column_info(
    connection: &mut sqlx::PgConnection,
    table_name: &str,
) -> Vec<ColumnTypeInfo> {
    let column_info = sqlx::query(
        "SELECT column_name, data_type, udt_name, is_nullable \
            FROM information_schema.columns \
            WHERE table_name = $1",
    )
    .bind(table_name)
    .fetch_all(connection)
    .await;

    assert_that!(&column_info)
        .named("Fetch column info")
        .is_ok();

    column_info
        .unwrap()
        .iter()
        .map(|row| {
            let data_type: String = row.get("data_type");
            let is_array: bool = data_type == "ARRAY";
            let is_nullable: String = row.get("is_nullable");

            ColumnTypeInfo {
                column_name: row.get("column_name"),
                data_type: if is_array {
                    get_type_of_array(row.get("udt_name")).unwrap().to_owned()
                } else {
                    data_type
                },
                is_array,
                is_nullable: is_nullable == "YES",
            }
        })
        .collect()
}
