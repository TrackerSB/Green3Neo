use std::fs;

use backend_paths::paths::get_user_config_dir;
use config::{FileFormat, FileStoredFormat};
use database_types::connection_description::ConnectionDescription;
use log::warn;
use sepa_types::creditor::Creditor;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Profile {
    pub creditor: Option<Creditor>,
    pub connection: Option<ConnectionDescription>,
}

static PROFILE_CONFIG_FILE_STEM: &str = "profile";
static PROFILE_CONFIG_FILE_FORMAT: FileFormat = FileFormat::Toml;

pub fn load_profile() -> Option<Profile> {
    let config_save_path = get_user_config_dir()
        .join(PROFILE_CONFIG_FILE_STEM)
        .with_extension(PROFILE_CONFIG_FILE_FORMAT.file_extensions()[0]);
    let serialized_profile = fs::read_to_string(&config_save_path);

    if serialized_profile.is_err() {
        warn!(
            "Could not read '{}' due to '{}'",
            config_save_path.display(),
            serialized_profile.err().unwrap()
        );
        return None;
    }

    let deserialized_profile = toml::from_str(serialized_profile.as_ref().unwrap());

    if deserialized_profile.is_err() {
        warn!(
            "Could not deserialize profile from string '{}' due to '{}'",
            serialized_profile.unwrap(),
            deserialized_profile.err().unwrap()
        );
        return None;
    }

    Some(deserialized_profile.unwrap())
}

pub fn save_profile(profile: Profile) {
    let config_save_path = get_user_config_dir()
        .join(PROFILE_CONFIG_FILE_STEM)
        .with_extension(PROFILE_CONFIG_FILE_FORMAT.file_extensions()[0]);
    let serialized_profile = toml::to_string_pretty(&profile);

    if serialized_profile.is_err() {
        warn!(
            "Could not serialize profile '{:?}' due to '{}'",
            profile,
            serialized_profile.err().unwrap()
        );
        return;
    }

    let write_result = std::fs::write(&config_save_path, serialized_profile.as_ref().unwrap());

    if write_result.is_err() {
        warn!(
            "Could not write serialized profile '{}' to file '{}'",
            serialized_profile.unwrap(),
            config_save_path.display()
        );
    }
}
