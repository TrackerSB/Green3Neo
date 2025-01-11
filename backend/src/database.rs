use diesel::backend::Backend;
use diesel::query_builder::bind_collector::RawBytesBindCollector;
use diesel::query_builder::BoxedSqlQuery;
use diesel::serialize::ToSql;
use diesel::sql_types::{Integer, Text, Varchar};
use diesel::{Connection, PgConnection, QueryableByName, RunQueryDsl};
use dotenv::dotenv;

pub fn get_connection() -> Option<PgConnection> {
    dotenv().ok();

    let url = std::env::var("DATABASE_URL");

    if url.is_err() {
        return None; // FIXME Improve error message
    }

    let connection = PgConnection::establish(&url.unwrap());

    if connection.is_err() {
        return None; // FIXME Improve error message
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
        // FIXME Either throw exception or log warning etc.
        println!("{}", derived_column_types.err().unwrap());
        return None;
    }

    assert!(derived_column_types.is_ok());

    let num_column_types = derived_column_types.as_ref().unwrap().len();
    if num_column_types == 0 {
        // FIXME Either throw exception or log warning etc.
        println!("Could not determine column type");
        return None;
    }
    if num_column_types > 1 {
        // FIXME Either throw exception or log warning etc.
        println!("Column type is ambiguous");
        return None;
    }

    Some(derived_column_types.unwrap().pop().unwrap())
}

pub fn bind_column_value<'a, DB, Query>(
    connection: &mut PgConnection,
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
    let column_type = determine_column_type(connection, "member", column_name);

    if column_type.is_none() {
        // FIXME Either throw exception or log warning etc.
        println!("Could not determine column type");
        return None;
    }

    let column_type = column_type.unwrap();

    let bound_query = match column_type.data_type.as_str() {
        "text" => sql_expression.bind::<Text, _>(value),
        "character varying" => sql_expression.bind::<Varchar, _>(value),
        "integer" => sql_expression.bind::<Integer, _>(value.parse::<i32>().unwrap()),
        _ => {
            println!("Unknown type {}", column_type.data_type.as_str());
            // FIXME Handle error
            return None;
        }
    };

    Some(bound_query)
}

#[cfg(test)]
mod test {
    use sqlx::{PgPool, Row};

    use super::*;

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

    #[sqlx::test]
    async fn test_determine_column_type(pool: PgPool) -> sqlx::Result<()> {
        let table_name = "alltypes";
        let mut test_connection = pool.acquire().await?;
        let creation_result = sqlx::query(&format!(
            "CREATE TABLE {}(\
                serialColumn SERIAL PRIMARY KEY,\
                integerColumn INTEGER NOT NULL,\
                textColumn TEXT NOT NULL,\
                varcharColumn VARCHAR NOT NULL\
            )",
            table_name
        ))
        .execute(test_connection.as_mut())
        .await;

        assert!(
            creation_result.is_ok(),
            "Creation of table failed due '{}'",
            creation_result.err().unwrap()
        );

        let column_info = sqlx::query(
            "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1",
        )
        .bind(table_name)
        .fetch_all(test_connection.as_mut())
        .await;

        assert!(
            column_info.is_ok(),
            "Fetching column info failed due '{}'",
            column_info.err().unwrap()
        );

        let mut diesel_connection = create_diesel_connection(test_connection.as_mut()).await;

        for row in column_info.unwrap().iter() {
            let column_name: String = row.try_get("column_name")?;
            let expected_data_type: String = row.try_get("data_type")?;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                determine_column_type(&mut diesel_connection, table_name, &column_name);
            assert!(
                opt_actual_column_type.is_some(),
                "Could not determine column type for column '{}'",
                column_name
            );
            let actual_column_type = opt_actual_column_type.unwrap();
            assert_eq!(actual_column_type.column_name, column_name);
            assert_eq!(actual_column_type.data_type, expected_data_type);
        }

        Ok(())
    }
}
