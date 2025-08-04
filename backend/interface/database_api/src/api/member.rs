use crate::api::models::Member;
use crate::database::{bind_column_value, get_connection};
use diesel::{query_dsl::methods::SelectDsl, sql_types::Integer, RunQueryDsl, SelectableHelper};
use log::{error, info, warn};

pub fn get_all_members() -> Option<Vec<Member>> {
    use crate::schema::member::dsl::*;

    let connection = get_connection();

    if connection.is_none() {
        // FIXME Either throw exception or log warning etc.
        error!("Could not establish connection");
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
    pub previous_value: Option<String>,
    pub new_value: Option<String>,
}

pub fn change_member(changes: Vec<ChangeRecord>) -> Vec<usize> {
    let connection = get_connection();

    if connection.is_none() {
        // FIXME Either throw exception or log warning etc.
        error!("Could not establish connection");
        return Vec::new();
    }

    let mut connection = connection.unwrap();

    info!("Changing {} members...", changes.len());

    let mut succeeded_update_indices: Vec<usize> = Vec::new();

    for (index, change) in changes.iter().enumerate() {
        // FIXME Determine primary key automatically
        // FIXME Prefer query builder over raw SQL
        let unbound_update_statement = diesel::sql_query(format!(
            "UPDATE member SET {} = $1 WHERE membershipid = $2",
            change.column
        ));

        if change.new_value.is_none() {
            // FIXME Verify whether column is nullable
            // FIXME Either throw exception or log warning etc.
            // FIXME Implement nullable case
            // FIXME Verify whether previous value corresponds to current value
            // let null_update_statement =
            //     unbound_update_statement.bind::<Nullable<Integer>, _>(None);
            // let update_statement = null_update_statement.bind::<Integer, _>(change.membershipid);
            // update_result = update_statement.execute(&mut connection);
            warn!("Changing values to NULL is not supported yet");
            continue;
        }

        let changed_value = change.new_value.as_ref();

        let boxed_unbound_update_statement = unbound_update_statement.into_boxed();
        let changed_value_update_statement = bind_column_value(
            &mut connection,
            "member",
            change.column.as_str(),
            changed_value.map(|s| s.as_str()),
            boxed_unbound_update_statement,
        )
        // FIXME Improve logging and error handling
        .expect("Could not bind column value");
        let update_statement =
            changed_value_update_statement.bind::<Integer, _>(change.membershipid);
        let update_result = update_statement.execute(&mut connection);

        // FIXME Improve logging and error handling
        match update_result {
            Ok(num_updated) => {
                info!("num updated {}", num_updated);
                if num_updated == 1 {
                    succeeded_update_indices.push(index);
                } else {
                    info!("Updated {} rows instead of 1", num_updated);
                }
            }
            Err(error) => {
                error!("error {}", error);
            }
        };
    }

    return succeeded_update_indices;
}
