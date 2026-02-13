#[cfg(test)]
mod test {
    use backend_testing::testing;
    use chrono::NaiveDate;
    use log::info;
    use sepa_types::debitor::Debitor;
    use sepa_types::iban::IBAN;
    use sepa_types::mandate::Mandate;
    use sepa_types::mandate_id::MandateID;
    use sepa_types::name::Name;

    use crate::api::{
        creditor::Creditor,
        generation::MessageID,
        generation::generate_sepa_document,
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
            name: Name {
                value: String::from("Gary Gathering"),
            },
            iban: IBAN {
                value: String::from("DE07123412341234123412"),
            },
        };

        let transactions = vec![Transaction {
            debitor: Debitor {
                name: Name {
                    value: String::from("Paying, Paula"),
                },
                iban: IBAN {
                    value: String::from("DE89370400440532013000"),
                },
                mandate: Mandate {
                    id: MandateID {
                        value: String::from("fancyMandateID"),
                    },
                    date_of_signature_utc: NaiveDate::from_ymd_opt(2024, 12, 12)
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
