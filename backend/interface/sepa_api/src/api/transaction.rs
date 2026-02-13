use sepa_types::{debitor::Debitor, purpose::Purpose};

pub struct Transaction {
    pub debitor: Debitor,
    pub value: f64,
    pub purpose: Purpose,
}
