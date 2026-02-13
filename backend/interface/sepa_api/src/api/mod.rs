pub mod creditor;
pub mod debitor;
pub mod generation;
pub mod init;
pub mod name;
pub mod transaction;

use flutter_rust_bridge::frb;
pub use sepa_types::iban::IBAN;

#[frb(mirror(IBAN))]
struct _IBAN {
    pub value: String,
}
