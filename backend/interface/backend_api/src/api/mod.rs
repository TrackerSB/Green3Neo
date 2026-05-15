pub mod init;
pub mod logging;
pub mod paths;
pub mod profile;

pub use database_types::connection_description::ConnectionDescription;
pub use database_types::connection_description::DatabaseBackend;
pub use database_types::connection_description::SshTunnelDescription;
use flutter_rust_bridge::frb;
pub use sepa_types::creditor::Creditor;
pub use sepa_types::creditor_id::CreditorID;
pub use sepa_types::iban::IBAN;
pub use sepa_types::name::Name;

// FIXME These definitions are duplicates and collide with the definitions in database_api and sepa_api
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

#[frb(mirror(Creditor))]
pub struct _Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}

#[frb(mirror(CreditorID))]
struct _CreditorID {
    pub value: String,
}

#[frb(mirror(IBAN))]
struct _IBAN {
    pub value: String,
}

#[frb(mirror(Name))]
struct _Name {
    pub value: String,
}
