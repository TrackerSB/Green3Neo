pub mod init;
pub mod member;
pub mod models;

pub use database_types::connection_description::ConnectionDescription;
pub use database_types::connection_description::DatabaseBackend;
use flutter_rust_bridge::frb;

#[frb(mirror(DatabaseBackend))]
pub enum _DatabaseBackend {
    MySql,
    PostgreSql,
}

#[frb(mirror(ConnectionDescription))]
pub struct _ConnectionDescription {
    pub backend: DatabaseBackend,
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
}
