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

    let bound_query: BoxedSqlQuery<'_, DB, Query> = match column_type.data_type.as_str() {
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
    use super::*;

    // #[test]
    // fn test_determine_column_type() {
    //     let conn = get_connection().unwrap();
    //     let column_type = determine_column_type(&conn, "users", "id");
    //     assert_eq!(column_type, "integer");
    // }
}
