use crate::api::models;
use crate::connection::DbConnection::OrmBased;
use crate::connection::DbConnection::SshBased;
use crate::connection::get_connection;
use crate::database::bind_column_value;
use database_types::connection_description::ConnectionDescription;
use diesel::{RunQueryDsl, sql_types::Integer};
use log::{error, info, warn};
use sea_query::Asterisk;
use sea_query::Expr;
use sea_query::Query;
use tokio::runtime::Runtime;

pub fn get_all_members(connection: ConnectionDescription) -> Option<Vec<models::Member>> {
    return Runtime::new().unwrap().block_on(async {
        let query = Query::select().column(Asterisk).from("member").to_owned();
        get_connection(connection).await?.load_member(query).await
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

pub fn change_member(connection: ConnectionDescription, changes: Vec<ChangeRecord>) -> usize {
    return Runtime::new().unwrap().block_on(async {
        let opt_connection = get_connection(connection).await;

        if opt_connection.is_none() {
            // FIXME Either throw exception or log warning etc.
            error!("Could not establish connection");
            return 0;
        }

        info!("Changing {} members...", changes.len());

        let mut change_entries = Vec::<(_, Expr)>::new();

        for change in changes.iter() {
            change_entries.push((
                change.column.clone(),
                change
                    .new_value
                    .clone()
                    .map_or(Expr::null(), |value| Expr::value(value)),
            ));
        }

        let update_statement = Query::update()
            .table("member")
            .values(change_entries)
            .to_owned();

        let mut connection = opt_connection.unwrap();
        let num_updated_rows = connection
            .execute_sql(connection.to_string(update_statement))
            .await;

        match num_updated_rows {
            Some(num) => num,
            None => {
                error!("Updating member failed");
                0
            }
        }
    });
}
