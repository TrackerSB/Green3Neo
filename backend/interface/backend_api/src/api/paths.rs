pub fn get_user_download_dir() -> String {
    backend_paths::paths::get_user_download_dir()
        .to_string_lossy()
        .to_string()
}
