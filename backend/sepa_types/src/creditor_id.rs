use serde::{Deserialize, Serialize};

// FIXME Add checks for valid creditor IDs
#[derive(Debug, Serialize, Deserialize)]
pub struct CreditorID {
    pub value: String,
}
