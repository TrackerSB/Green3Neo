use super::iban::IBAN;
use super::name::Name;

// FIXME Add checks for valid creditor IDs
pub type CreditorID = String;

pub struct Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}
