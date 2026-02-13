use chrono::NaiveDateTime;

use crate::mandate_id::MandateID;

// FIXME Can deriving from Clone be avoided?
#[derive(Debug, Clone)]
pub struct Mandate {
    pub id: MandateID,
    pub date_of_signature_utc: NaiveDateTime, // FIXME Should be NaiveDate
}
