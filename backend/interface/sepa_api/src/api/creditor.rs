use backend_paths::paths::get_user_config_dir;
use config::{Config, Environment, File, FileFormat, FileStoredFormat};
use log::warn;
use serde::{Deserialize, Serialize};

use super::iban::IBAN;
use super::name::Name;

// FIXME Add checks for valid creditor IDs
pub type CreditorID = String;

#[derive(Debug, Serialize, Deserialize)]
pub struct Creditor {
    pub name: Name,
    pub id: CreditorID,
    pub iban: IBAN,
}

static CREDITOR_CONFIG_FILE_STEM: &str = "creditor";
static CREDITOR_CONFIG_FILE_FORMAT: FileFormat = FileFormat::Toml;

pub fn get_configured_creditor() -> Option<Creditor> {
    let config_save_path = get_user_config_dir().join(CREDITOR_CONFIG_FILE_STEM);
    let config = Config::builder()
        .add_source(File::new(
            config_save_path.to_str().unwrap(),
            CREDITOR_CONFIG_FILE_FORMAT,
        ))
        .add_source(Environment::with_prefix(CREDITOR_CONFIG_FILE_STEM))
        .build()
        .expect("Could not read configuration");

    let creditor_name = config.get_string("name");
    let creditor_id = config.get_string("id");
    let creditor_iban = config.get_string("iban");

    if creditor_name.is_ok() && creditor_id.is_ok() && creditor_iban.is_ok() {
        return Some(Creditor {
            name: creditor_name.unwrap(),
            id: creditor_id.unwrap(),
            iban: creditor_iban.unwrap(),
        });
    }

    None
}

pub fn set_configured_creditor(creditor: Creditor) {
    let config_save_path = get_user_config_dir()
        .join(CREDITOR_CONFIG_FILE_STEM)
        .with_extension(CREDITOR_CONFIG_FILE_FORMAT.file_extensions()[0]);
    let serialized_creditor = toml::to_string_pretty(&creditor);

    if serialized_creditor.is_ok() {
        let write_result = std::fs::write(&config_save_path, serialized_creditor.as_ref().unwrap());

        if write_result.is_err() {
            warn!(
                "Could not write serialized creditor '{}' to file '{}'",
                serialized_creditor.unwrap(),
                config_save_path.display()
            );
        }
    } else {
        warn!(
            "Could not serialize creditor '{:?}' due to '{}'",
            creditor,
            serialized_creditor.err().unwrap()
        );
    }
}
