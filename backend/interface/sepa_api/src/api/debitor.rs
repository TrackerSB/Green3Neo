use sepa_types::iban::IBAN;
use sepa_types::mandate::Mandate;
use sepa_types::name::Name;

// FIXME Can deriving from Clone be avoided?
#[derive(Debug, Clone)]
pub struct Debitor {
    pub name: Name,
    pub iban: IBAN,
    pub mandate: Mandate,
}
