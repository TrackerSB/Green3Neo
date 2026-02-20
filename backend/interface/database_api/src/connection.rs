use database_types::connection_description::{ConnectionDescription, DatabaseBackend};
use diesel::{Connection, MultiConnection, MysqlConnection, PgConnection};
use log::warn;

#[derive(MultiConnection)]
pub enum DbConnection {
    MySql(MysqlConnection),
    PostgreSql(PgConnection),
}

pub fn get_connection(connection: ConnectionDescription) -> Option<DbConnection> {
    match connection.backend {
        DatabaseBackend::PostgreSql => {
            let database_url: String = format!(
                "postgres://{user}:{password}@{host}:{port}/{name}",
                user = connection.user,
                password = connection.password,
                host = connection.host,
                port = connection.port,
                name = connection.name
            );
            let connection = PgConnection::establish(&database_url);

            if connection.is_ok() {
                return Some(DbConnection::PostgreSql(connection.unwrap()));
            }

            warn!(
                "Connecting to database failed due '{}'",
                connection.err().unwrap()
            );
            return None;
        }
        DatabaseBackend::MySql => {
            let database_url: String = format!(
                "mysql://{user}:{password}@{host}:{port}/{name}",
                user = connection.user,
                password = connection.password,
                host = connection.host,
                port = connection.port,
                name = connection.name
            );
            let connection = MysqlConnection::establish(&database_url);

            if connection.is_ok() {
                return Some(DbConnection::MySql(connection.unwrap()));
            }

            warn!(
                "Connecting to database failed due '{}'",
                connection.err().unwrap()
            );
            return None;
        }
    }
}
