use std::{
    env::current_dir,
    path::{Path, PathBuf},
};

use directories::ProjectDirs;
use log::error;

fn create_dir_hierarchy(path: &&Path) -> bool {
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

fn canonicalize_path(path: &&Path) -> bool {
    let canonicalization_result = path.canonicalize();
    if canonicalization_result.is_ok() {
        return true;
    }

    error!(
        "Could not canonicalize path '{}' due to '{}'",
        path.display(),
        canonicalization_result.err().unwrap()
    );
    return false;
}

pub fn get_user_project_dir() -> PathBuf {
    // FIXME Take qualifier and application name from rust (maybe Cargo.toml?)
    let project_dirs = ProjectDirs::from("de.steinbrecher-bayern", "", "Green3Neo");

    let fallback_project_dir = current_dir().unwrap();

    let user_project_dir: PathBuf;
    if project_dirs.is_some() {
        user_project_dir = project_dirs
            .unwrap()
            .state_dir()
            .filter(create_dir_hierarchy)
            .filter(canonicalize_path)
            .map_or(fallback_project_dir, Path::to_owned);
    } else {
        error!(
            "Could not determine user project directories. Therefore defaulting to the current CWD"
        );
        user_project_dir = fallback_project_dir;
    }

    return user_project_dir;
}
