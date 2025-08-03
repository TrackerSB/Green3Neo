use std::sync::LazyLock;

use flexi_logger::LoggerHandle;
use flutter_rust_bridge::frb;
use backend_logging::logging::create_logger;

#[frb(init)]
pub fn init_app() {
    static LOGGER: LazyLock<LoggerHandle> = LazyLock::new(|| create_logger(None));
    LOGGER.flush(); // Trigger creation of logger
}
