use crate::api::models;
use crate::connection::DbConnection;
use crate::connection::get_connection;
use database_types::connection_description::ConnectionDescription;
use log::{error, info};
use sea_query::Asterisk;
use sea_query::Expr;
use sea_query::Query;
use tokio::runtime::Runtime;

async fn get_all_members_impl(mut connection: DbConnection) -> Option<Vec<models::Member>> {
    let query = Query::select().column(Asterisk).from("member").to_owned();
    connection.load_member(query).await
}

pub fn get_all_members(connection: ConnectionDescription) -> Option<Vec<models::Member>> {
    return Runtime::new()
        .unwrap()
        .block_on(async { get_all_members_impl(get_connection(connection).await?).await });
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

#[cfg(test)]
mod test {
    #[cfg(feature = "mysql")]
    use sqlx::MySqlPool;
    #[cfg(feature = "postgres")]
    use sqlx::PgPool;
    use sqlx::{Database, Pool, pool::PoolConnection};

    use crate::{
        connection::OrmConnection,
        test_database_common::{self, IntoDieselConnection},
    };

    use super::*;

    async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> OrmConnection
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        test_database_common::setup_test(sqlx_pool).await
    }

    fn tear_down(expected_num_severe_messages: usize) {
        test_database_common::tear_down(expected_num_severe_messages);
    }

    fn test_get_all(connection: DbConnection) -> sqlx::Result<()> {
        let _ = get_all_members_impl(connection);
        tear_down(0);
        Ok(())
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_get_all_pg(pool: PgPool) -> sqlx::Result<()> {
        test_get_all(DbConnection::OrmBased(setup_test(pool).await))
    }

    #[cfg(feature = "mysql")]
    #[sqlx::test]
    async fn test_get_all_mysql(pool: MySqlPool) -> sqlx::Result<()> {
        test_get_all(DbConnection::OrmBased(setup_test(pool).await))
    }
}
