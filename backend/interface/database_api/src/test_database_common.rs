use std::fs;

use backend_testing::testing;
use sqlx::{Database, Pool, any::install_default_drivers, pool::PoolConnection};

use crate::connection::OrmConnection;

trait GetCurrentDBName {
    async fn get_current_db_name(&mut self) -> Option<String>
    where
        Self: sqlx::Connection;
}

#[cfg(feature = "postgres")]
impl GetCurrentDBName for sqlx::PgConnection {
    async fn get_current_db_name(&mut self) -> Option<String> {
        Some(
            sqlx::query_scalar("SELECT current_database()")
                .fetch_one(self)
                .await
                .expect("Querying current database name failed"),
        )
    }
}

#[cfg(feature = "mysql")]
impl GetCurrentDBName for sqlx::MySqlConnection {
    async fn get_current_db_name(&mut self) -> Option<String> {
        todo!("Not implemented")
    }
}

fn create_db_url(db_name: &str) -> String {
    let template_db_url = std::env::var("DATABASE_URL").expect("Could not determine database URL");
    template_db_url
        .split_at(
            template_db_url
                .rfind("/")
                .expect("Could not find slash separating DB address from DB name")
                + 1,
        )
        .0
        .to_owned()
        + db_name
}

pub trait IntoDieselConnection {
    async fn into_diesel_connection(self) -> OrmConnection;
}

#[cfg(feature = "postgres")]
impl IntoDieselConnection for sqlx::pool::PoolConnection<sqlx::Postgres> {
    async fn into_diesel_connection(mut self) -> OrmConnection {
        use diesel::Connection;

        let db_name = self.get_current_db_name().await.unwrap();
        let db_url = create_db_url(&db_name);
        OrmConnection::PostgreSql(
            diesel::PgConnection::establish(&db_url).expect("Could not establish connection"),
        )
    }
}

#[cfg(feature = "mysql")]
impl IntoDieselConnection for sqlx::pool::PoolConnection<sqlx::MySql> {
    async fn into_diesel_connection(mut self) -> OrmConnection {
        use diesel::Connection;

        let db_name = self.get_current_db_name().await.unwrap();
        let db_url = create_db_url(&db_name);
        OrmConnection::MySql(
            diesel::MysqlConnection::establish(&db_url).expect("Could not establish connection"),
        )
    }
}

pub async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> OrmConnection
where
    DB: Database,
    PoolConnection<DB>: IntoDieselConnection,
{
    testing::setup_test();

    install_default_drivers(); // FIXME Required?

    let sqlx_connection = sqlx_pool.acquire().await.unwrap();
    let mut diesel_connection = sqlx_connection.into_diesel_connection().await;

    let fixture_sql_content = fs::read_to_string("src/fixtures/allsupportedtypes.sql").unwrap();
    diesel_connection.execute_sql(fixture_sql_content);

    diesel_connection
}

pub fn tear_down(expected_num_severe_messages: usize) {
    testing::tear_down(expected_num_severe_messages);
}
