use std::{
    env::current_dir,
    path::{Path, PathBuf},
};

use directories::{ProjectDirs, UserDirs};
use log::error;

pub fn create_dir_hierarchy(path: &PathBuf) -> bool {
    let creation_result = std::fs::create_dir_all(path);
    if creation_result.is_ok() {
        return true;
    }

    error!(
        "Could not create all directories of '{}' due to '{}'",
        path.display(),
        creation_result.err().unwrap()
    );
    return false;
}

pub fn canonicalize_path(path: PathBuf) -> Option<PathBuf> {
    if create_dir_hierarchy(&path) {
        let canonicalization_result = path.canonicalize();
        if canonicalization_result.is_ok() {
            return Some(path);
        }

        error!(
            "Could not canonicalize path '{}' due to '{}'",
            path.display(),
            canonicalization_result.err().unwrap()
        );
        return None;
    } else {
        return None;
    }
}

fn get_project_dir(get_dir: fn(&ProjectDirs) -> &Path) -> PathBuf {
    // FIXME Take qualifier and application name from rust (maybe Cargo.toml?)
    let project_dirs = ProjectDirs::from("de.steinbrecher-bayern", "", "Green3Neo");

    let fallback_project_dir = current_dir().unwrap();

    if project_dirs.is_some() {
        let unwrapped_project_dirs = project_dirs.unwrap();
        let desired_dir = get_dir(&unwrapped_project_dirs).to_owned();

        return canonicalize_path(desired_dir).unwrap_or(fallback_project_dir);
    }

    error!("Could not determine user project directories. Therefore defaulting to the current CWD");
    return fallback_project_dir;
}

pub fn get_user_data_dir() -> PathBuf {
    get_project_dir(ProjectDirs::data_dir)
}

pub fn get_user_download_dir() -> PathBuf {
    let user_dirs = UserDirs::new();
    if user_dirs.is_some() {
        let unwrapped_users_dir = user_dirs.unwrap();
        let download_dir = unwrapped_users_dir.download_dir();
        if download_dir.is_some() {
            return download_dir.unwrap().to_owned();
        }
    }

    error!("Could not determine users download dir. Therefore defaulting to the current CWD");
    current_dir().unwrap()
}

pub fn get_user_config_dir() -> PathBuf {
    get_project_dir(ProjectDirs::config_local_dir)
}
