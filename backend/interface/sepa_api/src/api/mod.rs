pub mod creditor;
pub mod generation;
pub mod init;

use chrono::NaiveDateTime;
use flutter_rust_bridge::frb;
pub use sepa_types::creditor::Creditor;
pub use sepa_types::creditor_id::CreditorID;
pub use sepa_types::debitor::Debitor;
pub use sepa_types::iban::IBAN;
pub use sepa_types::mandate::Mandate;
pub use sepa_types::mandate_id::MandateID;
pub use sepa_types::name::Name;
pub use sepa_types::purpose::Purpose;
pub use sepa_types::transaction::Transaction;

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

#[frb(mirror(Debitor))]
pub struct _Debitor {
    pub name: Name,
    pub iban: IBAN,
    pub mandate: Mandate,
}

#[frb(mirror(IBAN))]
struct _IBAN {
    pub value: String,
}

#[frb(mirror(Mandate))]
struct _Mandate {
    pub id: MandateID,
    pub date_of_signature_utc: NaiveDateTime,
}

#[frb(mirror(MandateID))]
struct _MandateID {
    pub value: String,
}

#[frb(mirror(Name))]
struct _Name {
    pub value: String,
}

#[frb(mirror(Purpose))]
struct _Purpose {
    pub value: String,
}

#[frb(mirror(Transaction))]
pub struct _Transaction {
    pub debitor: Debitor,
    pub value: f64,
    pub purpose: Purpose,
}
