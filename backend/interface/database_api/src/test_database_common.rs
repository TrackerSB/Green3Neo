use std::fs;
use std::ops::DerefMut;

use backend_testing::testing;
use database_types::connection_description::{
    ConnectionDescription, DatabaseBackend, SshTunnelDescription,
};
#[cfg(feature = "mysql")]
use sqlx::MySql;
#[cfg(feature = "postgres")]
use sqlx::Postgres;
use sqlx::{Database, Pool, any::install_default_drivers, pool::PoolConnection};

use crate::connection::{DbConnection, get_connection};

pub trait GetCurrentDBName {
    async fn get_current_db_name(connection: &mut PoolConnection<Self>) -> String
    where
        Self: Database;
}

#[cfg(feature = "postgres")]
impl GetCurrentDBName for Postgres {
    async fn get_current_db_name(connection: &mut PoolConnection<Self>) -> String {
        sqlx::query_scalar::<_, String>("SELECT current_database()")
            .fetch_one(connection.deref_mut())
            .await
            .expect("Querying current database name failed")
    }
}

#[cfg(feature = "mysql")]
impl GetCurrentDBName for MySql {
    async fn get_current_db_name(connection: &mut PoolConnection<Self>) -> String {
        sqlx::query_scalar::<_, String>("SELECT DATABASE()")
            .fetch_one(connection.deref_mut())
            .await
            .expect("Querying current database name failed")
    }
}

fn read_connection_from_environment() -> ConnectionDescription {
    let db_protocol = std::env::var("BUILD_DB_PROTOCOL").unwrap();
    let db_host = std::env::var("BUILD_DB_HOST").unwrap();
    let db_port = std::env::var("BUILD_DB_PORT").unwrap().parse().unwrap();
    let db_name = std::env::var("BUILD_DB_NAME").unwrap();
    let db_user = std::env::var("BUILD_DB_USER").unwrap();
    let db_password = std::env::var("BUILD_DB_PASSWORD").unwrap();

    let ssh_host = std::env::var("SSH_HOST");
    let ssh_port = std::env::var("SSH_PORT");
    let ssh_user = std::env::var("SSH_USER");
    let ssh_password = std::env::var("SSH_PASSWORD");

    let ssh_tunnel = if ssh_host.is_ok()
        && ssh_port.is_ok()
        && ssh_user.is_ok()
        && ssh_password.is_ok()
    {
        Some(SshTunnelDescription {
            host: ssh_host.unwrap(),
            port: ssh_port.unwrap().parse().unwrap(),
            password: ssh_password.unwrap(),
            username: ssh_user.unwrap(),
        })
    } else if ssh_host.is_err() && ssh_port.is_err() && ssh_user.is_err() && ssh_password.is_err() {
        None
    } else {
        panic!("SSH config is only partially set");
    };

    ConnectionDescription {
        backend: match db_protocol.as_str() {
            #[cfg(feature = "postgres")]
            "postgres" => DatabaseBackend::PostgreSql,
            #[cfg(feature = "mysql")]
            "mysql" => DatabaseBackend::MySql,
            _ => panic!("Unsupported DB protocol '{}'", db_protocol),
        },
        host: db_host,
        port: db_port,
        user: db_user,
        password: db_password,
        name: db_name,
        ssh_tunnel: ssh_tunnel,
    }
}

pub async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> DbConnection
where
    DB: Database + GetCurrentDBName,
{
    testing::setup_test();

    install_default_drivers(); // FIXME Required?

    let mut sqlx_connection = sqlx_pool.acquire().await.unwrap();

    let mut connection_description = read_connection_from_environment();
    connection_description.name = DB::get_current_db_name(&mut sqlx_connection).await;

    let mut connection = get_connection(connection_description).await.unwrap();

    let fixture_sql_content = fs::read_to_string("src/fixtures/allsupportedtypes.sql").unwrap();
    let _num_inserted_rows = connection.execute_sql(fixture_sql_content).await;
    // FIXME Verify whether all rows were inserted

    connection
}

pub fn tear_down(expected_num_severe_messages: usize) {
    testing::tear_down(expected_num_severe_messages);
}
