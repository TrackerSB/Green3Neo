use chrono::NaiveDateTime;

use sepa_types::iban::IBAN;
use sepa_types::mandate_id::MandateID;
use sepa_types::name::Name;

// FIXME Can deriving from Clone be avoided?
#[derive(Debug, Clone)]
pub struct Mandate {
    pub id: MandateID,
    pub date_of_signature_utc: NaiveDateTime, // FIXME Should be NaiveDate
}

// FIXME Can deriving from Clone be avoided?
#[derive(Debug, Clone)]
pub struct Debitor {
    pub name: Name,
    pub iban: IBAN,
    pub mandate: Mandate,
}
