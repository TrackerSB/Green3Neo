pub mod init;
pub mod member;
pub mod models;

pub use database_types::connection_description::ConnectionDescription;
use flutter_rust_bridge::frb;

#[frb(mirror(ConnectionDescription))]
pub struct _ConnectionDescription {
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
}
