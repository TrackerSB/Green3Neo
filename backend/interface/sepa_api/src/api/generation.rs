use std::io::Cursor;

use chrono::format::StrftimeItems;
use chrono::{Local, NaiveDateTime, SecondsFormat};
use chrono::{Locale, NaiveDate};
use xsd_parser_types::quick_xml::{SerializeSync, Writer};

use super::creditor::Creditor;
use super::creditor::CreditorID;
use super::debitor::Mandate;
use super::iban::IBAN;
use super::transaction::Transaction;

use crate::schemas::pain_008_001_11::*;

// FIXME Check restrictions on message ID
pub type MessageID = String;

fn generate_group_header(
    message_id: MessageID,
    num_transactions: usize,
    control_sum: f64,
) -> GroupHeader118Type {
    let creation_time = Local::now();

    GroupHeader118Type {
        msg_id: message_id,
        cre_dt_tm: creation_time.to_rfc3339_opts(SecondsFormat::Secs, true),
        authstn: vec![],
        nb_of_txs: num_transactions.to_string(),
        ctrl_sum: Some(control_sum),
        initg_pty: PartyIdentification272Type {
            nm: None,
            pstl_adr: None,
            id: None,
            ctry_of_res: None,
            ctct_dtls: None,
        },
        fwdg_agt: None, // FIXME What to put here?
    }
}

fn generate_creditor_info(name: &str) -> PartyIdentification272Type {
    PartyIdentification272Type {
        nm: Some(name.to_owned()),
        pstl_adr: None,
        id: None,
        ctry_of_res: None,
        ctct_dtls: None,
    }
}

fn generate_creditor_account(creditor_iban: IBAN) -> CashAccount40Type {
    CashAccount40Type {
        id: Some(AccountIdentification4ChoiceType::Iban(creditor_iban)),
        tp: None,
        ccy: None,
        nm: None,
        prxy: None,
    }
}

fn generate_creditor_scheme_id(creditor_id: CreditorID) -> PartyIdentification272Type {
    PartyIdentification272Type {
        nm: None,
        pstl_adr: None,
        id: Some(Party52ChoiceType::PrvtId(PersonIdentification18Type {
            dt_and_plc_of_birth: None,
            othr: vec![GenericPersonIdentification2Type {
                id: creditor_id,
                issr: None,
                schme_nm: Some(PersonIdentificationSchemeName1ChoiceType::Prtry(
                    String::from("SEPA"),
                )),
            }],
        })),
        ctry_of_res: None,
        ctct_dtls: None,
    }
}

fn generate_mandate_info(mandate: &Mandate) -> MandateRelatedInformation16Type {
    MandateRelatedInformation16Type {
        mndt_id: Some(mandate.id.to_owned()),
        dt_of_sgntr: Some(mandate.date_of_signature.to_string()),
        amdmnt_ind: None,
        amdmnt_inf_dtls: None,
        elctrnc_sgntr: None,
        frst_colltn_dt: None,
        fnl_colltn_dt: None,
        frqcy: None,
        rsn: None,
        trckg_days: None,
    }
}

fn generate_direct_debit_transaction(
    transaction: &Transaction,
) -> DirectDebitTransactionInformation32Type {
    DirectDebitTransactionInformation32Type {
        pmt_id: PaymentIdentification6Type {
            instr_id: None,
            end_to_end_id: String::from("NOTPROVIDED"),
            uetr: None,
        },
        pmt_tp_inf: None,
        instd_amt: ActiveOrHistoricCurrencyAndAmountType {
            ccy: String::from("EUR"),
            content: transaction.value,
        },
        chrg_br: None,
        drct_dbt_tx: Some(DirectDebitTransaction12Type {
            mndt_rltd_inf: Some(generate_mandate_info(&transaction.debitor.mandate)),
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
            nm: Some(transaction.debitor.name.clone()),
            pstl_adr: None,
            id: None,
            ctry_of_res: None,
            ctct_dtls: None,
        },
        dbtr_acct: CashAccount40Type {
            id: Some(AccountIdentification4ChoiceType::Iban(
                transaction.debitor.iban.to_owned(),
            )),
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
            ustrd: vec![transaction.purpose.to_owned()],
            strd: vec![],
        }),
        splmtry_data: vec![],
    }
}

fn generate_sepa_document_type(
    message_id: MessageID,
    collection_date: NaiveDate,
    creditor: Creditor,
    transactions: Vec<Transaction>,
) -> Document {
    let num_transactions = transactions.len();
    let control_sum = transactions.iter().map(|t| t.value).sum();

    Document {
        cstmr_drct_dbt_initn: CustomerDirectDebitInitiationV11Type {
            grp_hdr: generate_group_header(message_id, num_transactions, control_sum),
            pmt_inf: vec![PaymentInstruction45Type {
                pmt_inf_id: String::from("Fancy payment information ID"),
                pmt_mtd: PaymentMethod2CodeType::Dd,
                reqd_advc_tp: None,
                btch_bookg: Some(true),
                nb_of_txs: Some(num_transactions.to_string()),
                ctrl_sum: Some(control_sum),
                pmt_tp_inf: Some(PaymentTypeInformation29Type {
                    instr_prty: Some(Priority2CodeType::Norm),
                    svc_lvl: vec![ServiceLevel8ChoiceType::Cd(String::from("SEPA"))],
                    lcl_instrm: Some(LocalInstrument2ChoiceType::Cd(String::from("CORE"))),
                    seq_tp: Some(SequenceType3CodeType::Rcur),
                    ctgy_purp: None,
                }),
                reqd_colltn_dt: collection_date
                    .format_with_items(StrftimeItems::new_with_locale("%x", Locale::POSIX))
                    .to_string(),
                cdtr: generate_creditor_info(&creditor.name),
                cdtr_acct: generate_creditor_account(creditor.iban),
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
                cdtr_schme_id: Some(generate_creditor_scheme_id(creditor.id)),
                drct_dbt_tx_inf: transactions
                    .iter()
                    .map(|t| generate_direct_debit_transaction(t))
                    .collect(),
            }],
            splmtry_data: vec![],
        },
    }
}

pub fn generate_sepa_document(
    message_id: MessageID,
    collection_date: NaiveDateTime, // FIXME Should be NaiveDate
    creditor: Creditor,
    transactions: Vec<Transaction>,
) -> String {
    let document =
        generate_sepa_document_type(message_id, collection_date.date(), creditor, transactions);

    let output_storage = Cursor::new(Vec::<u8>::new());
    let mut writer = Writer::new_with_indent(output_storage, b' ', 4);
    document.serialize("document", &mut writer).unwrap();

    String::from_utf8(writer.into_inner().into_inner()).unwrap() // FIXME Handle error
}
