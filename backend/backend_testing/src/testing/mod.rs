use std::{
    collections::HashMap,
    sync::{Arc, LazyLock, RwLock},
    thread,
};

use backend_logging::logging::create_logger;
use flexi_logger::{LoggerHandle, writers::LogWriter};
use log::{info, warn};
use speculoos::assert_that;

fn get_current_thread_name() -> String {
    let thread_name = thread::current().name().map(|name| name.to_owned());
    if thread_name.is_some() {
        return thread_name.unwrap();
    }

    let fallback_thread_name = "unnamed";
    warn!(
        concat!(
            "Could not determine thread name. Using thread name '{}'. ",
            "If there are multiple such threads distinguishing them may be inaccurate."
        ),
        fallback_thread_name
    );
    return fallback_thread_name.to_owned();
}

fn get_message_entry_lock() -> Arc<RwLock<Vec<String>>> {
    static LOGGER: LazyLock<(
        LoggerHandle,
        Arc<RwLock<HashMap<String, Arc<RwLock<Vec<String>>>>>>,
    )> = LazyLock::new(|| {
        let test_case_name = std::env::var("NEXTEST_TEST_NAME").unwrap();
        let log_directory_name = format!("log_{}", test_case_name.replace("::", "_"));

        (
            create_logger(Some(Box::new(FailingWriter {})), &log_directory_name),
            Arc::new(RwLock::new(HashMap::new())),
        )
    });

    let unlocked_messages = LOGGER.1.clone();
    let mut locked_messages = unlocked_messages.write().unwrap();
    locked_messages
        .entry(get_current_thread_name())
        .or_insert(Arc::new(RwLock::new(Vec::new())))
        .clone()
}

pub fn setup_test() {
    let unlocked_message_entry = get_message_entry_lock();
    let mut locked_message_entry = unlocked_message_entry.write().unwrap();
    locked_message_entry.clear();
}

pub fn tear_down(expected_num_severe_messages: usize) {
    let current_num_severe_messages: Option<usize>;

    /* NOTE 2025-02-28 SHU: Destroy lock before checking number of severe messages (eventually throwing and
     * poisining the lock)
     */
    {
        let unlocked_message_entry = get_message_entry_lock();
        let locked_message_entry = unlocked_message_entry.read().unwrap();

        current_num_severe_messages = Some(locked_message_entry.len());
    }

    if current_num_severe_messages.is_some() {
        let current_num_severe_messages = current_num_severe_messages.unwrap();
        assert_that!(current_num_severe_messages)
            .named("Number of severe messages")
            .is_equal_to(expected_num_severe_messages);
    } else {
        warn!("Could not determine number of severe messages");
    }
}

pub struct FailingWriter {}

impl LogWriter for FailingWriter {
    fn write(
        &self,
        _now: &mut flexi_logger::DeferredNow,
        record: &log::Record,
    ) -> std::io::Result<()> {
        let is_severe_log_output: bool = record.level() <= log::Level::Warn;
        let message: String = record.args().to_string();
        let ignore_severe_message: bool =
            message.starts_with("slow statement: execution time exceeded alert threshold");
        if ignore_severe_message {
            info!("Ignoring severe message");
        } else {
            if is_severe_log_output {
                let unlocked_message_entry = get_message_entry_lock();
                let mut locked_message_entry = unlocked_message_entry.write().unwrap();
                locked_message_entry.push(message);
            }
        }
        Ok(())
    }

    fn flush(&self) -> std::io::Result<()> {
        Ok(())
    }
}
