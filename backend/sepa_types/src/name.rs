use serde::{Deserialize, Serialize};

// FIXME Add checks for valid names
// FIXME Can deriving from Clone be avoided?
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Name {
    pub value: String,
}
