use serde::{Deserialize, Serialize};

use crate::{creditor_id::CreditorID, iban::IBAN, name::Name};

#[derive(Debug, Serialize, Deserialize)]
pub struct Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}
