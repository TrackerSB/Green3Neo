use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DatabaseBackend {
    #[cfg(feature = "mysql")]
    MySql,
    #[cfg(feature = "postgres")]
    PostgreSql,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SshTunnelDescription {
    pub username: String,
    pub password: String,
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConnectionDescription {
    pub backend: DatabaseBackend,
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
    pub ssh_tunnel: Option<SshTunnelDescription>,
}
