use std::sync::LazyLock;

use backend_logging::logging::create_logger;
use flexi_logger::LoggerHandle;
use flutter_rust_bridge::frb;

#[frb(init)]
pub fn init_app() {
    // FIXME Determine library name automatically
    static LOGGER: LazyLock<LoggerHandle> = LazyLock::new(|| create_logger(None, "backend_api"));
    LOGGER.flush(); // Trigger creation of logger
}
