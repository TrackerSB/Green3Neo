use crate::iban::IBAN;
use crate::mandate::Mandate;
use crate::name::Name;

// FIXME Can deriving from Clone be avoided?
#[derive(Debug, Clone)]
pub struct Debitor {
    pub name: Name,
    pub iban: IBAN,
    pub mandate: Mandate,
}
