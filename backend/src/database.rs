use diesel::backend::Backend;
use diesel::query_builder::bind_collector::RawBytesBindCollector;
use diesel::query_builder::BoxedSqlQuery;
use diesel::serialize::ToSql;
use diesel::sql_types::{Integer, Text, Varchar};
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
struct ColumnTypeInfo {
    #[sql_type = "Text"]
    pub column_name: String,
    #[sql_type = "Text"]
    pub data_type: String,
}

fn determine_column_type(
    connection: &mut PgConnection,
    table_name: &str,
    column_name: &str,
) -> Option<ColumnTypeInfo> {
    let derived_column_types = diesel::sql_query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
    )
        .bind::<Varchar, _>(table_name)
        .bind::<Varchar, _>(column_name)
        .load::<ColumnTypeInfo>(connection);

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

    Some(derived_column_types.unwrap().pop().unwrap())
}

pub fn bind_column_value<'a, DB, Query>(
    connection: &mut PgConnection,
    table_name: &'a str,
    column_name: &'a str,
    value: &'a str,
    sql_expression: BoxedSqlQuery<'a, DB, Query>,
) -> Option<BoxedSqlQuery<'a, DB, Query>>
where
    DB: Backend<BindCollector<'a> = RawBytesBindCollector<DB>>,
    i32: ToSql<Integer, DB>,
    str: ToSql<Text, DB>,
    str: ToSql<Varchar, DB>,
{
    let column_type = determine_column_type(connection, table_name, column_name);

    if column_type.is_none() {
        warn!("Could not determine column type");
        return None;
    }

    let column_type = column_type.unwrap();

    let bound_query = match column_type.data_type.as_str() {
        "text" => sql_expression.bind::<Text, _>(value),
        "character varying" => sql_expression.bind::<Varchar, _>(value),
        "integer" => sql_expression.bind::<Integer, _>(value.parse::<i32>().unwrap()),
        _ => {
            warn!("Unknown type {}", column_type.data_type.as_str());
            return None;
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
    use log::error;
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
            assert!(!is_severe_log_output, "Encountered severe log output");
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
            "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1",
        )
        .bind(table_name)
        .fetch_all(connection)
        .await;

        assert!(
            column_info.is_ok(),
            "Fetching column info failed due '{}'",
            column_info.err().unwrap()
        );

        column_info
            .unwrap()
            .iter()
            .map(|row| ColumnTypeInfo {
                column_name: row.get("column_name"),
                data_type: row.get("data_type"),
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
        assert!(column_info.len() > 0, "No columns to check");

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

        for row in column_info.iter() {
            let expected_column_name = &row.column_name;
            let expected_data_type = &row.data_type;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                determine_column_type(&mut diesel_connection, table_name, &expected_column_name);
            assert!(
                opt_actual_column_type.is_some(),
                "Could not determine column type for column '{}'",
                expected_column_name
            );
            let actual_column_type = opt_actual_column_type.unwrap();
            assert_eq!(&actual_column_type.column_name, expected_column_name);
            assert_eq!(&actual_column_type.data_type, expected_data_type);
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
        assert!(column_info.len() > 0, "No columns to check");

        let mut diesel_connection = create_diesel_connection(&mut test_connection).await;

        for row in column_info.iter() {
            let value_to_bind: Option<&str> = match row.data_type.as_str() {
                "text" => Some("fancyText"),
                "character varying" => Some("fancyVarChar"),
                "integer" => Some("42"),
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

            assert!(sql_expression.is_some(), "Could not bind value to column");

            sql_expression
                .unwrap()
                .execute(&mut diesel_connection)
                .expect("Could not execute query");
        }

        Ok(())
    }
}
