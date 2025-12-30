#[cfg(test)]
mod test {
    use std::{io::BufWriter, thread::LocalKey};

    use backend_testing::testing;
    use chrono::{
        DateTime, FixedOffset, Local, Locale, NaiveDate, Offset, SecondsFormat, TimeZone, Utc,
        format::StrftimeItems,
    };
    use xsd_parser_types::quick_xml::{SerializeSync, Writer};

    fn setup_test() {
        testing::setup_test();
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    #[test]
    fn test_generate_sepa_xml() {
        use crate::api::schemas::pain_008_001_11::*;

        setup_test();

        let creation_time = FixedOffset::west_opt(0)
            .unwrap()
            .with_ymd_and_hms(2025, 12, 30, 0, 0, 0)
            .unwrap();

        let document = Document {
            cstmr_drct_dbt_initn: CustomerDirectDebitInitiationV11Type {
                grp_hdr: GroupHeader118Type {
                    msg_id: String::from("demo_msg_id"),
                    cre_dt_tm: creation_time.to_rfc3339_opts(SecondsFormat::Secs, true),
                    authstn: vec![],
                    nb_of_txs: String::from("1"),
                    ctrl_sum: Some(42f64),
                    initg_pty: PartyIdentification272Type {
                        nm: None,
                        pstl_adr: None,
                        id: None,
                        ctry_of_res: None,
                        ctct_dtls: None,
                    },
                    fwdg_agt: None, // FIXME What to put here?
                },
                pmt_inf: vec![PaymentInstruction45Type {
                    pmt_inf_id: String::from("Fancy payment information ID"),
                    pmt_mtd: PaymentMethod2CodeType::Dd,
                    reqd_advc_tp: None,
                    btch_bookg: Some(true),
                    nb_of_txs: Some(String::from("1")),
                    ctrl_sum: Some(42f64),
                    pmt_tp_inf: Some(PaymentTypeInformation29Type {
                        instr_prty: Some(Priority2CodeType::Norm),
                        svc_lvl: vec![ServiceLevel8ChoiceType::Cd(String::from("SEPA"))],
                        lcl_instrm: Some(LocalInstrument2ChoiceType::Cd(String::from("CORE"))),
                        seq_tp: Some(SequenceType3CodeType::Rcur),
                        ctgy_purp: None,
                    }),
                    reqd_colltn_dt: creation_time
                        .date_naive()
                        .format_with_items(StrftimeItems::new_with_locale("%x", Locale::POSIX))
                        .to_string(),
                    cdtr: PartyIdentification272Type {
                        nm: Some(String::from("Gary Gathering")),
                        pstl_adr: None,
                        id: None,
                        ctry_of_res: None,
                        ctct_dtls: None,
                    },
                    cdtr_acct: CashAccount40Type {
                        id: Some(AccountIdentification4ChoiceType::Iban(
                            String::from("DE07123412341234123412"), // Garys IBAN
                        )),
                        tp: None,
                        ccy: None,
                        nm: None,
                        prxy: None,
                    },
                    cdtr_agt: BranchAndFinancialInstitutionIdentification8Type {
                        fin_instn_id: FinancialInstitutionIdentification23Type {
                            bicfi: None,
                            clr_sys_mmb_id: None,
                            lei: None,
                            nm: None,
                            pstl_adr: None,
                            othr: Some(GenericFinancialIdentification1Type {
                                id: String::from("NOTPROVIDED"),
                                schme_nm: None,
                                issr: None,
                            }),
                        },
                        brnch_id: None,
                    },
                    cdtr_agt_acct: None,
                    ultmt_cdtr: None,
                    chrg_br: None,
                    chrgs_acct: None,
                    chrgs_acct_agt: None,
                    cdtr_schme_id: Some(PartyIdentification272Type {
                        nm: None,
                        pstl_adr: None,
                        id: Some(Party52ChoiceType::PrvtId(PersonIdentification18Type {
                            dt_and_plc_of_birth: None,
                            othr: vec![GenericPersonIdentification2Type {
                                id: String::from("DE98ZZZ09999999999"), // Garys creditor ID
                                issr: None,
                                schme_nm: Some(PersonIdentificationSchemeName1ChoiceType::Prtry(
                                    String::from("SEPA"),
                                )),
                            }],
                        })),
                        ctry_of_res: None,
                        ctct_dtls: None,
                    }),
                    drct_dbt_tx_inf: vec![DirectDebitTransactionInformation32Type {
                        pmt_id: PaymentIdentification6Type {
                            instr_id: None,
                            end_to_end_id: String::from("NOTPROVIDED"),
                            uetr: None,
                        },
                        pmt_tp_inf: None,
                        instd_amt: ActiveOrHistoricCurrencyAndAmountType {
                            ccy: String::from("EUR"),
                            content: 42f64,
                        },
                        chrg_br: None,
                        drct_dbt_tx: Some(DirectDebitTransaction12Type {
                            mndt_rltd_inf: Some(MandateRelatedInformation16Type {
                                mndt_id: Some(String::from("fancyMandateID")),
                                dt_of_sgntr: Some(String::from("2024-12-12")),
                                amdmnt_ind: None,
                                amdmnt_inf_dtls: None,
                                elctrnc_sgntr: None,
                                frst_colltn_dt: None,
                                fnl_colltn_dt: None,
                                frqcy: None,
                                rsn: None,
                                trckg_days: None,
                            }),
                            cdtr_schme_id: None,
                            pre_ntfctn_id: None,
                            pre_ntfctn_dt: None,
                        }),
                        ultmt_cdtr: None,
                        dbtr_agt: BranchAndFinancialInstitutionIdentification8Type {
                            fin_instn_id: FinancialInstitutionIdentification23Type {
                                bicfi: None,
                                clr_sys_mmb_id: None,
                                lei: None,
                                nm: None,
                                pstl_adr: None,
                                othr: Some(GenericFinancialIdentification1Type {
                                    id: String::from("NOTPROVIDED"),
                                    schme_nm: None,
                                    issr: None,
                                }),
                            },
                            brnch_id: None,
                        },
                        dbtr_agt_acct: None,
                        dbtr: PartyIdentification272Type {
                            nm: Some(String::from("Paying, Paula")),
                            pstl_adr: None,
                            id: None,
                            ctry_of_res: None,
                            ctct_dtls: None,
                        },
                        dbtr_acct: CashAccount40Type {
                            id: Some(AccountIdentification4ChoiceType::Iban(String::from(
                                "DE89370400440532013000",
                            ))),
                            tp: None,
                            ccy: None,
                            nm: None,
                            prxy: None,
                        },
                        ultmt_dbtr: None,
                        instr_for_cdtr_agt: None,
                        purp: None,
                        rgltry_rptg: vec![],
                        tax: None,
                        rltd_rmt_inf: vec![],
                        rmt_inf: Some(RemittanceInformation22Type {
                            ustrd: vec![String::from("Some reason for collecting money")],
                            strd: vec![],
                        }),
                        splmtry_data: vec![],
                    }],
                }],
                splmtry_data: vec![], // FIXME What to put here?
            },
        };

        let mut writer = std::fs::File::create("foo.xml").unwrap();
        let writer = BufWriter::new(&mut writer);
        let mut writer = Writer::new(writer);
        document.serialize("document", &mut writer).unwrap();

        // FIXME Validate XML against XSD

        tear_down(0);
    }
}
