use serde::{Deserialize, Serialize};

use crate::{creditor_id::CreditorID, iban::IBAN, name::Name};

// FIXME Can deriving from Clone be avoided?
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}
