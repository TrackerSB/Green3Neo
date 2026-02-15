use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub enum DatabaseBackend {
    MySql,
    PostgreSql,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConnectionDescription {
    pub backend: DatabaseBackend,
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
}
