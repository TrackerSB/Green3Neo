use std::{
    env::current_dir,
    path::{Path, PathBuf},
};

use directories::ProjectDirs;
pub use flexi_logger::LoggerHandle;
pub use flexi_logger::writers::LogWriter;
use flexi_logger::{
    AdaptiveFormat, Cleanup, Criterion, Duplicate, FileSpec, Logger, Naming, WriteMode,
    detailed_format,
};
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

fn get_user_project_dir() -> PathBuf {
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
            "Could not determine user log directories. Therefore putting a logging folder in the current CWD"
        );
        user_project_dir = fallback_project_dir;
    }

    return user_project_dir;
}

pub fn create_logger(additional_writer: Option<Box<dyn LogWriter>>) -> LoggerHandle {
    let logger_creation_result = Logger::try_with_env_or_str("info");
    if logger_creation_result.is_err() {
        panic!(
            "Could not create logger due '{}'",
            logger_creation_result.err().unwrap()
        );
    }

    let mut logger = logger_creation_result.unwrap().format(detailed_format);

    let user_project_dir = get_user_project_dir();
    let log_directory = user_project_dir.join("logs");

    let file_spec = FileSpec::default()
        .directory(&log_directory)
        .suppress_timestamp();
    if additional_writer.is_some() {
        logger = logger.log_to_file_and_writer(file_spec, additional_writer.unwrap());
    } else {
        logger = logger.log_to_file(file_spec);
    }

    logger = logger
        .duplicate_to_stderr(Duplicate::Warn)
        .adaptive_format_for_stderr(AdaptiveFormat::Detailed)
        .write_mode(WriteMode::Async)
        .rotate(
            Criterion::Size(1024 * 1024 * 1024), // 1 GB
            Naming::Numbers,
            Cleanup::KeepLogFiles(1),
        );

    let logger_config_result = logger.start_with_specfile(log_directory.join("logspec.toml"));

    if logger_config_result.is_err() {
        panic!(
            "Could not configure logger in directory '{}' due '{}'",
            log_directory.display(),
            logger_config_result.err().unwrap()
        );
    }

    logger_config_result.unwrap()
}
