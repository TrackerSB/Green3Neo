use serde::{Deserialize, Serialize};

// FIXME Add checks for valid IBANs
// FIXME Can deriving from Clone be avoided?
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct IBAN {
    pub iban: String,
}
