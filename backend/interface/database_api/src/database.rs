use chrono::NaiveDate;
use diesel::backend::Backend;
use diesel::query_builder::BoxedSqlQuery;
use diesel::serialize::ToSql;
use diesel::sql_types::{Bool, Date, Double, HasSqlType, Integer, Nullable, Text, Varchar};
use log::{info, warn};

use crate::column_type_info::get_column_info;
use crate::connection::OrmConnection;

pub fn bind_column_value<'a, DB, Query>(
    connection: &mut OrmConnection,
    table_name: &'a str,
    column_name: &'a str,
    value: Option<&'a str>,
    sql_expression: BoxedSqlQuery<'a, DB, Query>,
) -> Option<BoxedSqlQuery<'a, DB, Query>>
where
    DB: Backend + HasSqlType<Bool>,
    str: ToSql<Text, DB>,
    str: ToSql<Varchar, DB>,
    bool: ToSql<Bool, DB>,
    i32: ToSql<Integer, DB>,
    f64: ToSql<Double, DB>,
    NaiveDate: ToSql<Date, DB>,
{
    let column_type = get_column_info(connection, table_name, column_name);

    if column_type.is_none() {
        return None;
    }

    let column_type = column_type.unwrap();
    if value.is_none() && !column_type.is_nullable {
        warn!("Cannot bind non-nullable column '{}' to null", column_name);
        return None;
    }

    info!(
        "Binding column '{}' with type '{}' to value '{:?}'",
        column_name, column_type.data_type, value
    );

    fn parser<ResultType>(value: &str) -> Option<ResultType>
    where
        ResultType: std::str::FromStr,
        <ResultType as std::str::FromStr>::Err: std::fmt::Display,
        <ResultType as std::str::FromStr>::Err: std::fmt::Debug,
    {
        let parse_result = value.parse::<ResultType>();
        if parse_result.is_err() {
            warn!(
                "Could not parse value '{}' (expected type: {}) due '{}'. Ignoring result.",
                value,
                std::any::type_name::<ResultType>(),
                parse_result.err().unwrap()
            );
            None
        } else {
            Some(parse_result.unwrap())
        }
    }

    let bound_query =         // Handle non-array types
        match column_type.data_type.as_str() {
            "text" => sql_expression.bind::<Nullable<Text>, _>(value),
            "character varying" => sql_expression.bind::<Nullable<Varchar>, _>(value),
            "boolean" => {
                sql_expression.bind::<Nullable<Bool>, _>(value.map(parser::<bool>).flatten())
            }
            "integer" => {
                sql_expression.bind::<Nullable<Integer>, _>(value.map(parser::<i32>).flatten())
            }
            "double precision" => {
                sql_expression.bind::<Nullable<Double>, _>(value.map(parser::<f64>).flatten())
            }
            "date" => {
                sql_expression.bind::<Nullable<Date>, _>(value.map(parser::<NaiveDate>).flatten())
            }
            _ => {
                warn!(
                    "Cannot bind to unsupported type '{}'",
                    column_type.data_type.as_str()
                );
                return None;
            }
    };

    Some(bound_query)
}

#[cfg(test)]
mod test {
    use std::fs;

    use backend_testing::testing;
    #[cfg(feature = "mysql")]
    use sqlx::MySqlPool;
    #[cfg(feature = "postgres")]
    use sqlx::PgPool;
    use sqlx::{Database, Pool, any::install_default_drivers, pool::PoolConnection};

    use crate::test_database_common::IntoDieselConnection;

    use super::*;

    async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> OrmConnection
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        testing::setup_test();

        install_default_drivers(); // FIXME Required?

        let sqlx_connection = sqlx_pool.acquire().await.unwrap();
        let mut diesel_connection = sqlx_connection.into_diesel_connection().await;

        let fixture_sql_content = fs::read_to_string("src/fixtures/allsupportedtypes.sql").unwrap();
        diesel_connection.execute_sql(fixture_sql_content);

        diesel_connection
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_stub_pg(pool: PgPool) -> sqlx::Result<()> {
        let _connection = setup_test(pool).await;
        tear_down(0);
        Ok(())
    }

    #[cfg(feature = "mysql")]
    #[sqlx::test]
    async fn test_stub_mysql(pool: MySqlPool) -> sqlx::Result<()> {
        let _connection = setup_test(pool).await;
        tear_down(0);
        Ok(())
    }
}
