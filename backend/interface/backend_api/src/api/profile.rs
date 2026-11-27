use std::{
    fs,
    path::{Path, PathBuf},
};

use backend_paths::paths::get_user_config_dir;
use config::{FileFormat, FileStoredFormat};
use database_types::connection_description::ConnectionDescription;
use log::warn;
use sepa_types::creditor::Creditor;
use serde::{Deserialize, Serialize};

use crate::api::feature::{ALWAYS_ON_FEATURES, Feature};

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Profile {
    pub creditor: Option<Creditor>,
    pub connection: Option<ConnectionDescription>,
    // FIXME Separate system features from profile features
    // FIXME Use set like structure
    pub features: Vec<Feature>,
}

static PROFILE_CONFIG_FILE_STEM: &str = "profile";
static PROFILE_CONFIG_FILE_FORMAT: FileFormat = FileFormat::Toml;

fn get_profile_config_path() -> PathBuf {
    get_user_config_dir()
        .join(PROFILE_CONFIG_FILE_STEM)
        .with_extension(PROFILE_CONFIG_FILE_FORMAT.file_extensions()[0])
}

pub fn load_profile() -> Option<Profile> {
    load_profile_from_path(&get_profile_config_path())
}

fn load_profile_from_path(config_save_path: &Path) -> Option<Profile> {
    let serialized_profile = fs::read_to_string(config_save_path);

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

    let mut profile: Profile = deserialized_profile.unwrap();
    for feature in ALWAYS_ON_FEATURES.iter() {
        profile.features.push(feature.clone());
    }

    Some(profile)
}

pub fn save_profile(profile: Profile) {
    save_profile_to_path(profile, &get_profile_config_path());
}

fn save_profile_to_path(profile: Profile, config_save_path: &Path) {
    let serialized_profile = toml::to_string_pretty(&profile);

    if serialized_profile.is_err() {
        warn!(
            "Could not serialize profile '{:?}' due to '{}'",
            profile,
            serialized_profile.err().unwrap()
        );
        return;
    }

    let write_result = fs::write(config_save_path, serialized_profile.as_ref().unwrap());

    if write_result.is_err() {
        warn!(
            "Could not write serialized profile '{}' to file '{}'",
            serialized_profile.unwrap(),
            config_save_path.display()
        );
    }
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicUsize, Ordering},
    };

    use super::{Profile, load_profile_from_path, save_profile_to_path};
    use crate::api::feature::{ALWAYS_ON_FEATURES, Feature};

    struct TestProfilePath {
        path: PathBuf,
    }

    impl TestProfilePath {
        fn new() -> Self {
            static NEXT_ID: AtomicUsize = AtomicUsize::new(0);
            Self {
                path: std::env::temp_dir().join(format!(
                    "green3neo-profile-test-{}-{}.toml",
                    std::process::id(),
                    NEXT_ID.fetch_add(1, Ordering::Relaxed)
                )),
            }
        }
    }

    impl Drop for TestProfilePath {
        fn drop(&mut self) {
            if self.path.exists() {
                fs::remove_file(&self.path).expect("remove isolated profile test file");
            }
        }
    }

    #[test]
    fn saved_profile_can_be_loaded_with_its_features() {
        let test_file = TestProfilePath::new();
        let profile = Profile {
            features: vec![Feature::MemberView],
            ..Profile::default()
        };

        save_profile_to_path(profile, &test_file.path);
        let loaded_profile = load_profile_from_path(&test_file.path).expect("load saved profile");

        assert!(loaded_profile.features.contains(&Feature::MemberView));
        for feature in ALWAYS_ON_FEATURES.iter() {
            assert!(loaded_profile.features.contains(feature));
        }
    }

    #[test]
    fn loading_a_missing_profile_returns_none() {
        let test_file = TestProfilePath::new();

        assert!(load_profile_from_path(&test_file.path).is_none());
    }

    #[test]
    fn loading_malformed_toml_returns_none() {
        let test_file = TestProfilePath::new();
        fs::write(&test_file.path, "features = [").expect("write invalid profile");

        assert!(load_profile_from_path(&test_file.path).is_none());
    }

    #[test]
    fn loading_a_profile_with_an_invalid_field_type_returns_none() {
        let test_file = TestProfilePath::new();
        fs::write(&test_file.path, "features = 'not a list'").expect("write invalid profile");

        assert!(load_profile_from_path(&test_file.path).is_none());
    }

    #[test]
    fn loading_a_profile_with_missing_entries_uses_defaults() {
        let test_file = TestProfilePath::new();
        fs::write(&test_file.path, "").expect("write empty profile");

        let loaded_profile =
            load_profile_from_path(&test_file.path).expect("load profile with missing entries");

        assert!(loaded_profile.creditor.is_none());
        assert!(loaded_profile.connection.is_none());
        assert_eq!(loaded_profile.features.len(), ALWAYS_ON_FEATURES.len());
        for feature in ALWAYS_ON_FEATURES.iter() {
            assert!(loaded_profile.features.contains(feature));
        }
    }
}
