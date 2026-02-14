pub mod init;
pub mod logging;
pub mod paths;
pub mod profile;

pub use database_types::connection_description::ConnectionDescription;
use flutter_rust_bridge::frb;
pub use sepa_types::creditor::Creditor;
pub use sepa_types::creditor_id::CreditorID;
pub use sepa_types::iban::IBAN;
pub use sepa_types::name::Name;

// FIXME These definitions are duplicates and collide with the definitions in database_api and sepa_api
#[frb(mirror(ConnectionDescription))]
pub struct _ConnectionDescription {
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
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
