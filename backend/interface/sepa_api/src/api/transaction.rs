use sepa_types::debitor::Debitor;

// FIXME Add checks for valid purposes
pub type Purpose = String;

pub struct Transaction {
    pub debitor: Debitor,
    pub value: f64,
    pub purpose: Purpose,
}
