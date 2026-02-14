use serde::{Deserialize, Serialize};

// FIXME Add checks for valid creditor IDs
// FIXME Can deriving from Clone be avoided?
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CreditorID {
    pub value: String,
}
