pub mod init;
pub mod member;
pub mod models;

pub use database_types::connection_description::ConnectionDescription;
pub use database_types::connection_description::DatabaseBackend;
pub use database_types::connection_description::SshTunnelDescription;
use flutter_rust_bridge::frb;

#[frb(mirror(DatabaseBackend))]
pub enum _DatabaseBackend {
    #[cfg(feature = "mysql")]
    MySql,
    #[cfg(feature = "postgres")]
    PostgreSql,
}

#[frb(mirror(SshTunnelDescription))]
pub struct _SshTunnelDescription {
    pub username: String,
    pub password: String,
    pub host: String,
    pub port: u16,
}

#[frb(mirror(ConnectionDescription))]
pub struct _ConnectionDescription {
    pub backend: DatabaseBackend,
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
    pub ssh_tunnel: Option<SshTunnelDescription>,
}
