use std::sync::LazyLock;

use backend_logging::logging::create_logger;
use flexi_logger::LoggerHandle;
use flutter_rust_bridge::frb;

#[frb(init)]
pub fn init_app() {
    static LOGGER: LazyLock<LoggerHandle> = LazyLock::new(|| create_logger(None));
    LOGGER.flush(); // Trigger creation of logger

    let metadata = std::fs::metadata("/home/runner/.local/share/green3neo/logs");
    if metadata.is_ok() {
        println!("Metadata of log dir: {:?}", metadata);
    } else {
        println!("Could not retrieve metadata of log dir");
    }
}
