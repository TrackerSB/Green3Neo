use log::error;
use log::info;
use log::warn;

pub fn info(message: String) {
    info!("{}", message);
}

pub fn warn(message: String) {
    warn!("{}", message);
}

pub fn error(message: String) {
    error!("{}", message);
}
