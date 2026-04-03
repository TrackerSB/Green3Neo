use log::warn;

use diesel::{
    QueryableByName, RunQueryDsl,
    result::Error,
    sql_types::{Text, Varchar},
};

use crate::connection::DbConnection;

#[derive(Clone, Debug)]
pub struct ColumnTypeInfo {
    pub column_name: String,
    pub data_type: String,
    pub is_nullable: bool,
}

#[derive(QueryableByName, Debug)]
struct ColumnTypeRequestResult {
    #[diesel(sql_type = Text)]
    pub column_name: String,
    #[diesel(sql_type = Text)]
    pub data_type: String,
    #[diesel(sql_type = Text)]
    pub udt_name: String,
    #[diesel(sql_type = Text)]
    pub is_nullable: String,
}

fn convert_to_column_info(
    derived_column_types: Result<Vec<ColumnTypeRequestResult>, Error>,
) -> Vec<ColumnTypeInfo> {
    if derived_column_types.is_err() {
        warn!(
            "Could not determine column types due '{}'",
            derived_column_types.err().unwrap()
        );
        return vec![];
    }

    derived_column_types
        .unwrap()
        .iter()
        .map(|result: &ColumnTypeRequestResult| ColumnTypeInfo {
            column_name: result.column_name.clone(),
            data_type: result.data_type.clone(),
            is_nullable: result.is_nullable == "YES",
        })
        .collect()
}

pub fn get_column_info(
    connection: &mut DbConnection,
    table_name: &str,
    column_name: &str,
) -> Option<ColumnTypeInfo> {
    let column_info_result = diesel::sql_query(
        "SELECT column_name, data_type, udt_name, is_nullable \
        FROM information_schema.columns \
        WHERE table_name = $1 AND column_name = $2",
    )
    .bind::<Varchar, _>(table_name)
    .bind::<Varchar, _>(column_name)
    .load::<ColumnTypeRequestResult>(connection);
    convert_to_column_info(column_info_result)
        .iter()
        .find(|column_info: &&ColumnTypeInfo| column_info.column_name == column_name)
        .cloned()
}

pub fn get_all_column_info(connection: &mut DbConnection, table_name: &str) -> Vec<ColumnTypeInfo> {
    let column_info_result = diesel::sql_query(
        "SELECT column_name, data_type, udt_name, is_nullable \
            FROM information_schema.columns \
            WHERE table_name = $1",
    )
    .bind::<Varchar, _>(table_name)
    .load::<ColumnTypeRequestResult>(connection);

    convert_to_column_info(column_info_result)
}

#[cfg(test)]
mod test {
    use std::fs;

    use crate::test_database_common::IntoDieselConnection;
    use backend_testing::testing;
    use speculoos::{assert_that, option::OptionAssertions, vec::VecAssertions};
    use sqlx::any::install_default_drivers;
    use sqlx::pool::PoolConnection;
    use sqlx::{Database, PgPool, Pool};

    use super::*;

    async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> DbConnection
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        testing::setup_test();

        install_default_drivers(); // FIXME Required?

        let sqlx_connection = sqlx_pool.acquire().await.unwrap();
        let mut diesel_connection = sqlx_connection.into_diesel_connection().await;

        let fixture_sql_content = fs::read_to_string("src/fixtures/allsupportedtypes.sql").unwrap();
        diesel::sql_query(fixture_sql_content)
            .execute(&mut diesel_connection)
            .unwrap();

        diesel_connection
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    async fn test_determine_column_type<DB>(pool: Pool<DB>) -> sqlx::Result<()>
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        let mut diesel_connection = setup_test(pool).await;

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";

        let column_info = get_all_column_info(&mut diesel_connection, table_name);
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        for row in column_info.iter() {
            let expected_column_name = &row.column_name;
            let expected_data_type = &row.data_type;
            let expected_is_nullable = &row.is_nullable;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                get_column_info(&mut diesel_connection, table_name, &expected_column_name);
            assert_that!(&opt_actual_column_type)
                .named("Determine column type")
                .is_some()
                .matches(|actual_column_type| {
                    &actual_column_type.column_name == expected_column_name
                })
                .matches(|actual_column_type| &actual_column_type.data_type == expected_data_type)
                .matches(|actual_column_type| {
                    &actual_column_type.is_nullable == expected_is_nullable
                });
        }

        tear_down(0);
        Ok(())
    }

    #[sqlx::test]
    async fn test_determine_column_type_pg(pool: PgPool) -> sqlx::Result<()> {
        test_determine_column_type(pool).await
    }
}
