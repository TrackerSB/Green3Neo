use database_types::connection_description::ConnectionDescription;
use database_types::connection_description::DatabaseBackend;
#[cfg(feature = "mysql")]
use diesel::MysqlConnection;
#[cfg(feature = "postgres")]
use diesel::PgConnection;
use diesel::{Connection, MultiConnection};
use log::warn;

#[derive(MultiConnection)]
pub enum OrmConnection {
    #[cfg(feature = "mysql")]
    MySql(MysqlConnection),
    #[cfg(feature = "postgres")]
    PostgreSql(PgConnection),
}

pub fn get_connection(connection: ConnectionDescription) -> Option<OrmConnection> {
    match connection.backend {
        #[cfg(feature = "postgres")]
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
                return Some(OrmConnection::PostgreSql(connection.unwrap()));
            }

            warn!(
                "Connecting to database failed due '{}'",
                connection.err().unwrap()
            );
            return None;
        }
        #[cfg(feature = "mysql")]
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
                return Some(OrmConnection::MySql(connection.unwrap()));
            }

            warn!(
                "Connecting to database failed due '{}'",
                connection.err().unwrap()
            );
            return None;
        }
    }
}
