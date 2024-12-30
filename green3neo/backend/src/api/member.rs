use crate::models::Member;
use diesel::{
    query_dsl::methods::SelectDsl,
    result::Error,
    sql_types::{Integer, Text, Varchar},
    Connection, PgConnection, QueryResult, QueryableByName, RunQueryDsl, SelectableHelper,
};
use dotenv::dotenv;

fn get_connection() -> Option<PgConnection> {
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

pub fn get_all_members() -> Option<Vec<Member>> {
    use crate::schema::member::dsl::*;

    let connection = get_connection();

    if connection.is_none() {
        // FIXME Either throw exception or log warning etc.
        println!("Could not establish connection");
        return None;
    }

    let member_entries = member
        .select(Member::as_select())
        .load(&mut connection.unwrap());

    if member_entries.is_err() {
        return None; // FIXME Improve error message
    }

    Some(member_entries.unwrap())
}

pub struct ChangeRecord {
    // Primary key for identification
    pub membershipid: i32,

    // Data to change
    pub column: String,
    // FIXME How to transport type information for value or even derive it from column?
    pub value: Option<String>,
}

#[derive(QueryableByName, Debug)]
pub struct ColumnTypeInfo {
    #[sql_type = "Text"]
    pub column_name: String,
    #[sql_type = "Text"]
    pub data_type: String,
}

fn determine_column_type(column_name: &str) -> Option<ColumnTypeInfo> {
    let connection = get_connection();

    if connection.is_none() {
        return None;
    }

    let mut connection = connection.unwrap();

    let derived_column_types = diesel::sql_query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'member' AND column_name = $1",
    )
        .bind::<Varchar, _>(column_name)
        .load::<ColumnTypeInfo>(&mut connection);
    if derived_column_types.is_err() || (derived_column_types.as_ref().unwrap().len() != 1) {
        return None;
    }

    Some(derived_column_types.unwrap().pop().unwrap())
}

pub fn change_member(changes: Vec<ChangeRecord>) -> Vec<usize> {
    let connection = get_connection();

    if connection.is_none() {
        // FIXME Either throw exception or log warning etc.
        println!("Could not establish connection");
        return Vec::new();
    }

    let mut connection = connection.unwrap();

    println!("Changing {} members...", changes.len());

    let mut succeeded_update_indices: Vec<usize> = Vec::new();

    for (index, change) in changes.iter().enumerate() {
        let column_type = determine_column_type(change.column.as_str());

        if column_type.is_none() {
            // FIXME Either throw exception or log warning etc.
            println!("Could not determine column type");
            continue;
        }

        let column_type = column_type.unwrap();

        // FIXME Determine primary key automatically
        // FIXME Prefer query builder over raw SQL
        let unbound_update_statement = diesel::sql_query(format!(
            "UPDATE member SET {} = $1 WHERE membershipid = $2",
            change.column
        ));

        let changed_value = change.value.as_ref();
        let mut update_result: QueryResult<usize> = Err(Error::NotFound);

        if changed_value.is_none() {
            // FIXME Verify whether column is nullable
            // FIXME Either throw exception or log warning etc.
            // FIXME Implement nullable case
            // let null_update_statement =
            //     unbound_update_statement.bind::<Nullable<Integer>, _>(None);
            // let update_statement = null_update_statement.bind::<Integer, _>(change.membershipid);
            // update_result = update_statement.execute(&mut connection);
            println!("Changing values to NULL is not supported yet");
            continue;
        } else {
            let boxed_unbound_update_statement = unbound_update_statement.into_boxed();
            let changed_value_update_statement = match column_type.data_type.as_str() {
                "text" => boxed_unbound_update_statement.bind::<Text, _>(changed_value.unwrap()),
                "character varying" => {
                    boxed_unbound_update_statement.bind::<Varchar, _>(changed_value.unwrap())
                }
                "integer" => boxed_unbound_update_statement
                    .bind::<Integer, _>(changed_value.unwrap().parse::<i32>().unwrap()),
                _ => {
                    println!("Unknown type {}", column_type.data_type.as_str());
                    // FIXME Handle error
                    continue;
                }
            };
            let update_statement =
                changed_value_update_statement.bind::<Integer, _>(change.membershipid);
            update_result = update_statement.execute(&mut connection);
        }

        // FIXME Improve logging and error handling
        match update_result {
            Ok(num_updated) => {
                println!("num updated {}", num_updated);
                if num_updated == 1 {
                    succeeded_update_indices.push(index);
                } else {
                    println!("Updated {} rows instead of 1", num_updated);
                }
            }
            Err(error) => {
                println!("error {}", error);
            }
        };
    }

    return succeeded_update_indices;
}
