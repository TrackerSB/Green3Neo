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

fn determine_column_type(table_name: &str, column_name: &str) -> Option<ColumnTypeInfo> {
    let connection = get_connection();

    if connection.is_none() {
        return None;
    }

    let mut connection = connection.unwrap();

    let derived_column_types = diesel::sql_query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
    )
        .bind::<Varchar, _>(table_name)
        .bind::<Varchar, _>(column_name)
        .load::<ColumnTypeInfo>(&mut connection);
    if derived_column_types.is_err() || (derived_column_types.as_ref().unwrap().len() != 1) {
        return None;
    }

    Some(derived_column_types.unwrap().pop().unwrap())
}

pub fn bind_column_value<'a, DB, Query>(
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
    let column_type = determine_column_type("member", column_name);

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

    #[sqlx::test]
    async fn test_determine_column_type(pool: PgPool) -> sqlx::Result<()> {
        let table_name = "alltypes";
        let mut connection = pool.acquire().await?;
        sqlx::query(&format!(
            "CREATE TABLE {}(\
                serial SERIAL PRIMARY KEY,\
                integer INTEGER NOT NULL,\
                text TEXT NOT NULL,\
                varchar VARCHAR NOT NULL\
            )",
            table_name
        ))
        .execute(connection.as_mut())
        .await?;
        let column_info = sqlx::query(
            "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1",
        )
        .bind(table_name)
        .fetch_all(connection.as_mut())
        .await?;

        for row in column_info.iter() {
            let column_name: String = row.try_get("column_name")?;
            let expected_data_type: String = row.try_get("data_type")?;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                determine_column_type(table_name, &column_name);
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
