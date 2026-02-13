use std::fs;

use backend_paths::paths::get_user_config_dir;
use config::{FileFormat, FileStoredFormat};
use log::warn;
use sepa_types::iban::IBAN;
use sepa_types::name::Name;
use serde::{Deserialize, Serialize};

// FIXME Add checks for valid creditor IDs
#[derive(Debug, Serialize, Deserialize)]
pub struct CreditorID {
    pub value: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}

static CREDITOR_CONFIG_FILE_STEM: &str = "creditor";
static CREDITOR_CONFIG_FILE_FORMAT: FileFormat = FileFormat::Toml;

pub fn get_configured_creditor() -> Option<Creditor> {
    let config_save_path = get_user_config_dir()
        .join(CREDITOR_CONFIG_FILE_STEM)
        .with_extension(CREDITOR_CONFIG_FILE_FORMAT.file_extensions()[0]);
    let serialized_creditor = fs::read_to_string(&config_save_path);

    if serialized_creditor.is_err() {
        warn!(
            "Could not read '{}' due to '{}'",
            config_save_path.display(),
            serialized_creditor.err().unwrap()
        );
        return None;
    }

    let deserialized_creditor = toml::from_str(serialized_creditor.as_ref().unwrap());

    if deserialized_creditor.is_err() {
        warn!(
            "Could not deserialize creditor from string '{}' due to '{}'",
            serialized_creditor.unwrap(),
            deserialized_creditor.err().unwrap()
        );
        return None;
    }

    Some(deserialized_creditor.unwrap())
}

pub fn set_configured_creditor(creditor: Creditor) {
    let config_save_path = get_user_config_dir()
        .join(CREDITOR_CONFIG_FILE_STEM)
        .with_extension(CREDITOR_CONFIG_FILE_FORMAT.file_extensions()[0]);
    let serialized_creditor = toml::to_string_pretty(&creditor);

    if serialized_creditor.is_err() {
        warn!(
            "Could not serialize creditor '{:?}' due to '{}'",
            creditor,
            serialized_creditor.err().unwrap()
        );
        return;
    }

    let write_result = std::fs::write(&config_save_path, serialized_creditor.as_ref().unwrap());

    if write_result.is_err() {
        warn!(
            "Could not write serialized creditor '{}' to file '{}'",
            serialized_creditor.unwrap(),
            config_save_path.display()
        );
    }
}
