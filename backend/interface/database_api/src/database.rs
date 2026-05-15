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
    use diesel::RunQueryDsl;
    use log::error;
    use speculoos::{assert_that, option::OptionAssertions, vec::VecAssertions};
    #[cfg(feature = "postgres")]
    use sqlx::PgPool;
    use sqlx::{Database, Pool, any::install_default_drivers, pool::PoolConnection};

    use crate::{
        column_type_info::get_all_column_info, connection::MultiBackend,
        test_database_common::IntoDieselConnection,
    };

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
        diesel::sql_query(fixture_sql_content)
            .execute(&mut diesel_connection)
            .unwrap();

        diesel_connection
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    async fn test_bind_column<DB>(pool: Pool<DB>) -> sqlx::Result<()>
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut diesel_connection = setup_test(pool).await;

        let column_info = get_all_column_info(&mut diesel_connection, table_name);
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        for row in column_info.iter() {
            let value_to_bind: Option<&str> = match row.data_type.as_str() {
                "text" => Some("fancyText"),
                "character varying" => Some("fancyVarChar"),
                "boolean" => Some("false"),
                "integer" => Some("42"),
                "double precision" => Some("123.123"),
                "date" => Some("2021-01-01"),
                _ => {
                    error!("No testdata defined for type {}", row.data_type);
                    None
                }
            };

            if value_to_bind.is_none() {
                error!("No test case for type {}", row.data_type.as_str());
                continue;
            }

            let base_sql_expression = diesel::sql_query(format!(
                "SELECT {1} FROM {0} WHERE {1} = $1",
                table_name, row.column_name
            ));

            let sql_expression_with_value = bind_column_value(
                &mut diesel_connection,
                &table_name,
                &row.column_name,
                value_to_bind,
                base_sql_expression.clone().into_boxed(),
            );

            assert_that!(&sql_expression_with_value.as_ref().map(|_| ()))
                .named("Bind column value")
                .is_some();

            sql_expression_with_value
                .unwrap()
                .execute(&mut diesel_connection)
                .expect("Could not execute query");

            if row.is_nullable {
                let sql_expression_with_null = bind_column_value(
                    &mut diesel_connection,
                    &table_name,
                    &row.column_name,
                    None,
                    base_sql_expression.into_boxed(),
                );

                assert_that!(&sql_expression_with_null.as_ref().map(|_| ()))
                    .named("Bind column to null")
                    .is_some();

                sql_expression_with_null
                    .unwrap()
                    .execute(&mut diesel_connection)
                    .expect("Could not execute query");
            }
        }

        tear_down(0);
        Ok(())
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_bind_column_pg(pool: PgPool) -> sqlx::Result<()> {
        test_bind_column(pool).await
    }

    async fn test_bind_wrong_type<DB>(pool: Pool<DB>) -> sqlx::Result<()>
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut diesel_connection = setup_test(pool).await;

        let column_info = get_all_column_info(&mut diesel_connection, table_name);
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let column_name = "datecolumn";
        let value_to_bind = Some("true");

        let base_sql_expression = diesel::sql_query(format!(
            "SELECT {1} FROM {0} WHERE {1} = $1",
            table_name, column_name
        ));

        let sql_expression = bind_column_value(
            &mut diesel_connection,
            &table_name,
            &column_name,
            value_to_bind,
            base_sql_expression.into_boxed(),
        );

        assert_that!(&sql_expression.as_ref().map(|_| ()))
            .named("Bind column value")
            .is_some();

        sql_expression
            .unwrap()
            .execute(&mut diesel_connection)
            .expect("Could not execute query");

        tear_down(1);
        Ok(())
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_bind_wrong_type_pg(pool: PgPool) -> sqlx::Result<()> {
        test_bind_wrong_type(pool).await
    }

    async fn test_bind_null_to_nonnullable_column<DB>(pool: Pool<DB>) -> sqlx::Result<()>
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut diesel_connection = setup_test(pool).await;

        let column_info = get_all_column_info(&mut diesel_connection, table_name);
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let column_name = "doublecolumn";
        let value_to_bind = None;

        let base_sql_expression = diesel::sql_query(format!(
            "SELECT {1} FROM {0} WHERE {1} = $1",
            table_name, column_name
        ));

        let sql_expression: Option<BoxedSqlQuery<'_, MultiBackend, _>> = bind_column_value(
            &mut diesel_connection,
            &table_name,
            &column_name,
            value_to_bind,
            base_sql_expression.into_boxed(),
        );

        assert_that!(&sql_expression.as_ref().map(|_| ()))
            .named("Bind column value")
            .is_none();

        tear_down(1);
        Ok(())
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_bind_null_to_nonnullable_column_pg(pool: PgPool) -> sqlx::Result<()> {
        test_bind_null_to_nonnullable_column(pool).await
    }
}
