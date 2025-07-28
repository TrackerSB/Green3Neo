use chrono::NaiveDate;
use diesel::backend::Backend;
use diesel::query_builder::bind_collector::RawBytesBindCollector;
use diesel::query_builder::BoxedSqlQuery;
use diesel::serialize::ToSql;
use diesel::sql_types::{Array, Bool, Date, Double, HasSqlType, Integer, Nullable, Text, Varchar};
use diesel::{Connection, PgConnection, QueryableByName, RunQueryDsl};
use dotenv::dotenv;
use log::{info, trace, warn};

pub fn get_connection() -> Option<PgConnection> {
    dotenv().ok();

    let url = std::env::var("DATABASE_URL");

    if url.is_err() {
        warn!("Could not determine database URL");
        return None;
    }

    let connection = PgConnection::establish(&url.unwrap());

    if connection.is_err() {
        warn!(
            "Connecting to database failed due '{}'",
            connection.err().unwrap()
        );
        return None;
    }

    Some(connection.unwrap())
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

#[derive(Debug)]
struct ColumnTypeInfo {
    pub column_name: String,
    pub data_type: String,
    pub is_array: bool,
    pub is_nullable: bool,
}

fn convert_array_type(array_type: &str) -> Option<&str> {
    match array_type {
        "_int4" => Some("integer"),
        _ => None,
    }
}

fn determine_column_type(
    connection: &mut PgConnection,
    table_name: &str,
    column_name: &str,
) -> Option<ColumnTypeInfo> {
    let query = diesel::sql_query(
        "SELECT column_name, data_type, udt_name, is_nullable \
        FROM information_schema.columns \
        WHERE table_name = $1 AND column_name = $2",
    )
    .bind::<Varchar, _>(table_name)
    .bind::<Varchar, _>(column_name);
    trace!("query: {:?}", query);
    let derived_column_types = query.load::<ColumnTypeRequestResult>(connection);

    if derived_column_types.is_err() {
        warn!(
            "Could not determine column types due '{}'",
            derived_column_types.err().unwrap()
        );
        return None;
    }

    assert!(derived_column_types.is_ok());

    let num_column_types = derived_column_types.as_ref().unwrap().len();
    if num_column_types == 0 {
        warn!("Could not determine column type of '{}'", column_name);
        return None;
    }
    if num_column_types > 1 {
        warn!("Column type is ambiguous");
        return None;
    }

    let column_type_result: ColumnTypeRequestResult = derived_column_types.unwrap().pop().unwrap();
    let is_array = column_type_result.data_type == "ARRAY";
    let is_nullable = column_type_result.is_nullable == "YES";

    if is_array {
        let array_type = convert_array_type(column_type_result.udt_name.as_str());
        if array_type.is_none() {
            warn!("Unknown array type {}", column_type_result.udt_name);
            return None;
        }
        return Some(ColumnTypeInfo {
            column_name: column_type_result.column_name,
            data_type: array_type.unwrap().to_owned(),
            is_array,
            is_nullable,
        });
    }

    Some(ColumnTypeInfo {
        column_name: column_type_result.column_name,
        data_type: column_type_result.data_type,
        is_array,
        is_nullable,
    })
}

pub fn bind_column_value<'a, DB, Query>(
    connection: &mut PgConnection,
    table_name: &'a str,
    column_name: &'a str,
    value: Option<&'a str>,
    sql_expression: BoxedSqlQuery<'a, DB, Query>,
) -> Option<BoxedSqlQuery<'a, DB, Query>>
where
    DB: Backend<BindCollector<'a> = RawBytesBindCollector<DB>>
        + HasSqlType<Array<Integer>>
        + HasSqlType<Bool>,
    str: ToSql<Text, DB>,
    str: ToSql<Varchar, DB>,
    bool: ToSql<Bool, DB>,
    i32: ToSql<Integer, DB>,
    Vec<i32>: ToSql<Array<Integer>, DB>,
    f64: ToSql<Double, DB>,
    NaiveDate: ToSql<Date, DB>,
{
    let column_type = determine_column_type(connection, table_name, column_name);

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

    let bound_query = if column_type.is_array {
        // Handle array types
        let elements = value.map(|v| v.split(","));
        match column_type.data_type.as_str() {
            "integer" => {
                sql_expression.bind::<Nullable<Array<Integer>>, _>(elements.map(|split| {
                    split
                        .map(|element| parser::<i32>(element).unwrap())
                        .collect::<Vec<i32>>()
                }))
            }
            _ => {
                warn!(
                    "Cannot bind to unsupported array type '{}'",
                    column_type.data_type.as_str()
                );
                return None;
            }
        }
    } else {
        // Handle non-array types
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
        }
    };

    Some(bound_query)
}

#[cfg(test)]
mod test {
    use backend::logging::create_logger;
    use flexi_logger::{writers::LogWriter, LoggerHandle};
    use log::{error, info};
    use speculoos::{
        assert_that, option::OptionAssertions, result::ResultAssertions, vec::VecAssertions,
    };
    use sqlx::{PgPool, Row};
    use std::{
        collections::HashMap,
        sync::{Arc, LazyLock, RwLock},
        thread,
    };

    use super::*;

    fn get_message_entry_lock() -> Arc<RwLock<Vec<String>>> {
        static LOGGER: LazyLock<(
            LoggerHandle,
            Arc<RwLock<HashMap<String, Arc<RwLock<Vec<String>>>>>>,
        )> = LazyLock::new(|| {
            (
                create_logger(Some(Box::new(FailingWriter {}))),
                Arc::new(RwLock::new(HashMap::new())),
            )
        });

        let unlocked_messages = LOGGER.1.clone();
        let mut locked_messages = unlocked_messages.write().unwrap();
        locked_messages
            .entry(get_current_thread_name())
            .or_insert(Arc::new(RwLock::new(Vec::new())))
            .clone()
    }

    fn get_current_thread_name() -> String {
        let thread_name = thread::current().name().map(|name| name.to_owned());
        if thread_name.is_some() {
            return thread_name.unwrap();
        }

        let fallback_thread_name = "unnamed";
        warn!(
            concat!(
                "Could not determine thread name. Using thread name '{}'. ",
                "If there are multiple such threads distinguishing them may be inaccurate."
            ),
            fallback_thread_name
        );
        return fallback_thread_name.to_owned();
    }

    struct FailingWriter {}

    impl LogWriter for FailingWriter {
        fn write(
            &self,
            _now: &mut flexi_logger::DeferredNow,
            record: &log::Record,
        ) -> std::io::Result<()> {
            let is_severe_log_output: bool = record.level() <= log::Level::Warn;
            let message: String = record.args().to_string();
            let ignore_severe_message: bool =
                message.starts_with("slow statement: execution time exceeded alert threshold");
            if ignore_severe_message {
                info!("Ignoring severe message");
            } else {
                if is_severe_log_output {
                    let unlocked_message_entry = get_message_entry_lock();
                    let mut locked_message_entry = unlocked_message_entry.write().unwrap();
                    locked_message_entry.push(message);
                }
            }
            Ok(())
        }

        fn flush(&self) -> std::io::Result<()> {
            Ok(())
        }
    }

    fn setup_test() {
        let unlocked_message_entry = get_message_entry_lock();
        let mut locked_message_entry = unlocked_message_entry.write().unwrap();
        locked_message_entry.clear();
    }

    fn tear_down(expected_num_severe_messages: usize) {
        let current_num_severe_messages: Option<usize>;

        /* NOTE 2025-02-28 SHU: Destroy lock before checking number of severe messages (eventually throwing and
         * poisining the lock)
         */
        {
            let unlocked_message_entry = get_message_entry_lock();
            let locked_message_entry = unlocked_message_entry.read().unwrap();

            current_num_severe_messages = Some(locked_message_entry.len());
        }

        if current_num_severe_messages.is_some() {
            let current_num_severe_messages = current_num_severe_messages.unwrap();
            assert_that!(current_num_severe_messages)
                .named("Number of severe messages")
                .is_equal_to(expected_num_severe_messages);
        } else {
            warn!("Could not determine number of severe messages");
        }
    }

    // Create a diesel based connection to the same database
    async fn create_diesel_connection(
        sqlx_connection: &mut sqlx::PgConnection,
    ) -> diesel::PgConnection {
        let test_db_name: String = sqlx::query_scalar!("SELECT current_database()")
            .fetch_one(sqlx_connection)
            .await
            .expect("Querying current database name failed")
            .expect("Result database name is empty");

        let configured_url =
            std::env::var("DATABASE_URL").expect("Could not determine database URL");

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

        PgConnection::establish(&test_db_url).expect("Could not establish connection")
    }

    async fn get_column_info(
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
                        convert_array_type(row.get("udt_name")).unwrap().to_owned()
                    } else {
                        data_type
                    },
                    is_array,
                    is_nullable: is_nullable == "YES",
                }
            })
            .collect()
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_determine_column_type(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

        for row in column_info.iter() {
            let expected_column_name = &row.column_name;
            let expected_data_type = &row.data_type;
            let expected_is_array = &row.is_array;
            let expected_is_nullable = &row.is_nullable;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                determine_column_type(&mut diesel_connection, table_name, &expected_column_name);
            assert_that!(&opt_actual_column_type)
                .named("Determine column type")
                .is_some()
                .matches(|actual_column_type| {
                    &actual_column_type.column_name == expected_column_name
                })
                .matches(|actual_column_type| &actual_column_type.data_type == expected_data_type)
                .matches(|actual_column_type| &actual_column_type.is_array == expected_is_array)
                .matches(|actual_column_type| {
                    &actual_column_type.is_nullable == expected_is_nullable
                });
        }

        tear_down(0);
        Ok(())
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_bind_column(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

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

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_bind_wrong_type(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

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

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_bind_null_to_nonnullable_column(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

        let column_name = "doublecolumn";
        let value_to_bind = None;

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
            .is_none();

        tear_down(1);
        Ok(())
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_column_case_sensitivity(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

        let column_name = "doubleCOLUMN";
        let value_to_bind = Some("42.");

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
            .is_none();

        tear_down(1);
        Ok(())
    }
}
