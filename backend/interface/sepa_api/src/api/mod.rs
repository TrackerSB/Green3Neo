pub mod creditor;
pub mod debitor;
pub mod generation;
pub mod init;
pub mod transaction;

use flutter_rust_bridge::frb;
pub use sepa_types::iban::IBAN;
pub use sepa_types::name::Name;

#[frb(mirror(IBAN))]
struct _IBAN {
    pub value: String,
}

#[frb(mirror(Name))]
struct _Name {
    pub value: String,
}
