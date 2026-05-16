use crate::api::models;
use crate::connection::DbConnection::OrmBased;
use crate::connection::DbConnection::SshBased;
use crate::connection::OrmConnection;
use crate::connection::SshConnection;
use crate::connection::get_connection;
use crate::database::bind_column_value;
use crate::schema::member::dsl as member_schema;
use database_types::connection_description::ConnectionDescription;
use diesel::{RunQueryDsl, SelectableHelper, query_dsl::methods::SelectDsl, sql_types::Integer};
use log::{error, info, warn};
use sea_query::Query;
use tokio::runtime::Runtime;

fn get_all_members_orm(mut connection: OrmConnection) -> Option<Vec<models::Member>> {
    let member_entries = member_schema::member
        .select(models::Member::as_select())
        .load(&mut connection);

    if member_entries.is_ok() {
        return Some(member_entries.unwrap());
    }

    return None;
}

async fn get_all_members_ssh(_connection: SshConnection) -> Option<Vec<models::Member>> {
    error!("SSH connection not supported");
    return None;
}

pub fn get_all_members(connection: ConnectionDescription) -> Option<Vec<models::Member>> {
    return Runtime::new().unwrap().block_on(async {
        let opt_connection = get_connection(connection).await;

        if opt_connection.is_none() {
            // FIXME Either throw exception or log warning etc.
            error!("Could not establish connection");
            return None;
        }

        return match opt_connection.unwrap() {
            OrmBased(connection) => get_all_members_orm(connection),
            SshBased(connection) => get_all_members_ssh(connection).await,
        };
    });
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

pub fn change_member(connection: ConnectionDescription, changes: Vec<ChangeRecord>) -> Vec<usize> {
    return Runtime::new().unwrap().block_on(async {
        let opt_connection = get_connection(connection).await;

        if opt_connection.is_none() {
            // FIXME Either throw exception or log warning etc.
            error!("Could not establish connection");
            return Vec::new();
        }

        info!("Changing {} members...", changes.len());

        let mut succeeded_update_indices: Vec<usize> = Vec::new();

        match opt_connection.unwrap() {
            OrmBased(mut connection) => {
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
            }
            SshBased(_connection) => error!("SSH based connections are not supported"),
        }

        return succeeded_update_indices;
    });
}
