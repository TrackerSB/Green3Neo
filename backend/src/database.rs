use chrono::NaiveDate;
use diesel::backend::Backend;
use diesel::query_builder::bind_collector::RawBytesBindCollector;
use diesel::query_builder::BoxedSqlQuery;
use diesel::serialize::ToSql;
use diesel::sql_types::{Array, Bool, Date, Double, HasSqlType, Integer, Text, Varchar};
use diesel::{Connection, PgConnection, QueryableByName, RunQueryDsl};
use dotenv::dotenv;
use log::warn;

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
    #[sql_type = "Text"]
    pub column_name: String,
    #[sql_type = "Text"]
    pub data_type: String,
    #[sql_type = "Text"]
    pub udt_name: String,
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
    let derived_column_types = diesel::sql_query(
        "SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
    )
        .bind::<Varchar, _>(table_name)
        .bind::<Varchar, _>(column_name)
        .load::<ColumnTypeRequestResult>(connection);

    if derived_column_types.is_err() {
        warn!("{}", derived_column_types.err().unwrap());
        return None;
    }

    assert!(derived_column_types.is_ok());

    let num_column_types = derived_column_types.as_ref().unwrap().len();
    if num_column_types == 0 {
        warn!("Could not determine column type");
        return None;
    }
    if num_column_types > 1 {
        warn!("Column type is ambiguous");
        return None;
    }

    let column_type_result: ColumnTypeRequestResult = derived_column_types.unwrap().pop().unwrap();
    if column_type_result.data_type == "ARRAY" {
        let array_type = convert_array_type(column_type_result.udt_name.as_str());
        if array_type.is_none() {
            warn!("Unknown array type {}", column_type_result.udt_name);
            return None;
        }
        return Some(ColumnTypeInfo {
            column_name: column_type_result.column_name,
            data_type: array_type.unwrap().to_owned(),
            is_array: true,
            // FIXME Detect nullable
            is_nullable: false,
        });
    }

    Some(ColumnTypeInfo {
        column_name: column_type_result.column_name,
        data_type: column_type_result.data_type,
        is_array: false,
        // FIXME Detect nullable
        is_nullable: false,
    })
}

pub fn bind_column_value<'a, DB, Query>(
    connection: &mut PgConnection,
    table_name: &'a str,
    column_name: &'a str,
    value: &'a str,
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
        warn!("Could not determine column type");
        return None;
    }

    let column_type = column_type.unwrap();

    let bound_query = if column_type.is_array {
        let elements = value.split(",");
        match column_type.data_type.as_str() {
            "integer" => sql_expression.bind::<Array<Integer>, _>(
                elements
                    .map(|element| element.parse::<i32>())
                    .map(|element| element.unwrap())
                    .collect::<Vec<i32>>(),
            ),
            _ => {
                warn!(
                    "Cannot bind to unsupported array type {}",
                    column_type.data_type.as_str()
                );
                return None;
            }
        }
    } else {
        match column_type.data_type.as_str() {
            "text" => sql_expression.bind::<Text, _>(value),
            "character varying" => sql_expression.bind::<Varchar, _>(value),
            "boolean" => sql_expression.bind::<Bool, _>(value.parse::<bool>().unwrap()),
            "integer" => sql_expression.bind::<Integer, _>(value.parse::<i32>().unwrap()),
            "double precision" => sql_expression.bind::<Double, _>(value.parse::<f64>().unwrap()),
            "date" => sql_expression.bind::<Date, _>(value.parse::<NaiveDate>().unwrap()),
            _ => {
                warn!(
                    "Cannot bind to unsupported type {}",
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
    use flexi_logger::{
        detailed_format, writers::LogWriter, AdaptiveFormat, Cleanup, Criterion, Duplicate,
        FileSpec, Logger, LoggerHandle, Naming, WriteMode,
    };
    use log::{error, info};
    use speculoos::{
        assert_that, option::OptionAssertions, prelude::BooleanAssertions,
        result::ResultAssertions, vec::VecAssertions,
    };
    use sqlx::{PgPool, Row};
    use std::sync::Once;

    use super::*;

    static INIT: Once = Once::new();
    static mut LOGGER: Option<LoggerHandle> = None;

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
                assert_that(&is_severe_log_output)
                    .named("Severe log output")
                    .is_false();
            }
            Ok(())
        }

        fn flush(&self) -> std::io::Result<()> {
            Ok(())
        }
    }

    fn setup_tests() {
        INIT.call_once(|| {
            unsafe {
                LOGGER = Some(
                    Logger::try_with_env_or_str("info")
                        .unwrap()
                        .format(detailed_format)
                        // FIXME Where to put files based on CWD, environment, installation folder etc.?
                        .log_to_file_and_writer(
                            FileSpec::default().directory("./logs").suppress_timestamp(),
                            Box::new(FailingWriter {}),
                        )
                        .duplicate_to_stderr(Duplicate::Warn)
                        .adaptive_format_for_stderr(AdaptiveFormat::Detailed)
                        .write_mode(WriteMode::Async)
                        .rotate(
                            Criterion::Size(1024 * 1024 * 1024), // 1 GB
                            Naming::Numbers,
                            Cleanup::KeepLogFiles(1),
                        )
                        // FIXME Where to put files based on CWD, environment, installation folder etc.?
                        .start_with_specfile("./logs/logspec.toml")
                        .unwrap(),
                )
            };
        });
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
            "SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name = $1",
        )
        .bind(table_name)
        .fetch_all(connection)
        .await;

        assert_that(&column_info).named("Fetch column info").is_ok();

        column_info
            .unwrap()
            .iter()
            .map(|row| {
                let data_type: String = row.get("data_type");
                let is_array: bool = data_type == "ARRAY";

                ColumnTypeInfo {
                    column_name: row.get("column_name"),
                    data_type: if is_array {
                        convert_array_type(row.get("udt_name")).unwrap().to_owned()
                    } else {
                        data_type
                    },
                    is_array,
                    // FIXME Detect nullable
                    is_nullable: false,
                }
            })
            .collect()
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_determine_column_type(pool: PgPool) -> sqlx::Result<()> {
        setup_tests();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that(&column_info)
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
            assert_that(&opt_actual_column_type)
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

        Ok(())
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_bind_column(pool: PgPool) -> sqlx::Result<()> {
        setup_tests();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_column_info(&mut test_connection, table_name).await;
        assert_that(&column_info)
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

            let sql_expression = bind_column_value(
                &mut diesel_connection,
                &table_name,
                &row.column_name,
                value_to_bind.unwrap(),
                base_sql_expression.into_boxed(),
            );

            assert_that(&sql_expression.as_ref().map(|_| ()))
                .named("Bind column value")
                .is_some();

            sql_expression
                .unwrap()
                .execute(&mut diesel_connection)
                .expect("Could not execute query");
        }

        Ok(())
    }
}
