use flexi_logger::{
    detailed_format, writers::LogWriter, AdaptiveFormat, Cleanup, Criterion, Duplicate, FileSpec,
    Logger, LoggerHandle, Naming, WriteMode,
};

pub fn create_logger(writer: Option<Box<dyn LogWriter>>) -> LoggerHandle {
    let logger_creation_result = Logger::try_with_env_or_str("info");
    if logger_creation_result.is_err() {
        panic!(
            "Could not create logger due '{}'",
            logger_creation_result.err().unwrap()
        );
    }

    let mut logger = logger_creation_result.unwrap().format(detailed_format);

    // FIXME Where to put files based on CWD, environment, installation folder etc.?
    let file_spec = FileSpec::default().directory("./logs").suppress_timestamp();
    if writer.is_some() {
        logger = logger.log_to_file_and_writer(file_spec, writer.unwrap());
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

    // FIXME Where to put files based on CWD, environment, installation folder etc.?
    let logger_config_result = logger.start_with_specfile("./logs/logspec.toml");

    if logger_config_result.is_err() {
        panic!(
            "Could not configure logger due '{}'",
            logger_config_result.err().unwrap()
        );
    }

    logger_config_result.unwrap()
}
