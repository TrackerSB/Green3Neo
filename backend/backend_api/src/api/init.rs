use std::sync::LazyLock;

use super::logging::create_logger;
use flexi_logger::LoggerHandle;
use flutter_rust_bridge::frb;

#[frb(init)]
pub fn init_app() {
    static LOGGER: LazyLock<LoggerHandle> = LazyLock::new(|| create_logger(None));
    LOGGER.flush(); // Trigger creation of logger
}
