use std::env::current_dir;

use backend_paths::paths::{canonicalize_path, get_user_data_dir};
pub use flexi_logger::LoggerHandle;
pub use flexi_logger::writers::LogWriter;
use flexi_logger::{
    AdaptiveFormat, Cleanup, Criterion, Duplicate, FileSpec, Logger, Naming, WriteMode,
    detailed_format,
};

pub fn create_logger(additional_writer: Option<Box<dyn LogWriter>>) -> LoggerHandle {
    let logger_creation_result = Logger::try_with_env_or_str("info");
    if logger_creation_result.is_err() {
        panic!(
            "Could not create logger due '{}'",
            logger_creation_result.err().unwrap()
        );
    }

    let mut logger = logger_creation_result.unwrap().format(detailed_format);

    let user_project_dir = get_user_data_dir();
    let log_directory_path = user_project_dir.join("logs");
    let log_directory =
        canonicalize_path(log_directory_path).unwrap_or_else(|| current_dir().unwrap());

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
