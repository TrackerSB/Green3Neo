#[cfg(test)]
mod test {
    use backend_testing::testing;
    use chrono::NaiveDate;
    use log::info;

    use crate::api::{
        creditor::Creditor,
        debitor::{Debitor, Mandate, MandateID},
        generation::MessageID,
        generation::generate_sepa_document,
        iban::IBAN,
        name::Name,
        transaction::{Purpose, Transaction},
    };

    fn setup_test() {
        testing::setup_test();
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    #[test]
    fn test_generate_sepa_xml() {
        setup_test();

        let message_id = MessageID::from("demo_msg_id");

        let collection_date = NaiveDate::from_ymd_opt(2026, 3, 15)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap(); // FIXME Handle error

        let creditor = Creditor {
            id: String::from("DE98ZZZ09999999999"),
            name: Name::from("Gary Gathering"),
            iban: IBAN::from("DE07123412341234123412"),
        };

        let transactions = vec![Transaction {
            debitor: Debitor {
                name: Name::from("Paying, Paula"),
                iban: IBAN::from("DE89370400440532013000"),
                mandate: Mandate {
                    id: MandateID::from("fancyMandateID"),
                    date_of_signature: NaiveDate::from_ymd_opt(2024, 12, 12)
                        .unwrap()
                        .and_hms_opt(0, 0, 0)
                        .unwrap(), // FIXME Handle error
                },
            },
            value: 42f64,
            purpose: Purpose::from("Some unknown reason for collecting money"),
        }];

        let xml_content =
            generate_sepa_document(message_id, collection_date, creditor, transactions);

        info!("{}", xml_content);

        // FIXME Validate XML against XSD

        tear_down(0);
    }
}
