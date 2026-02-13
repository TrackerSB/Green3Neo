use sepa_types::debitor::Debitor;

// FIXME Add checks for valid purposes
pub struct Purpose {
    pub value: String,
}

pub struct Transaction {
    pub debitor: Debitor,
    pub value: f64,
    pub purpose: Purpose,
}
