use std::process::{exit, Command};
use dotenv::dotenv;

fn main() {
    // Load local environment variables
    dotenv().ok();

    // Find GCC include dir
    let clang_output_child = Command::new("clang")
        .args(&["-v"])
        .output()
        .expect("Could not collect clang output");

    if !clang_output_child.status.success() {
        eprintln!("cargo:error=Could not receive clang output");
        exit(1);
    }

    let clang_output = String::from_utf8_lossy(&clang_output_child.stderr);
    let mut gcc_installation_lines = clang_output
        .lines()
        .filter(|&line| line.starts_with("Selected GCC installation"));

    let gcc_installation_line = gcc_installation_lines.next();

    let additional_gcc_installation_line = gcc_installation_lines.next();
    if additional_gcc_installation_line.is_some() {
        eprintln!("cargo:error=The GCC installation directory is ambigous");
        exit(1);
    }

    let gcc_include_dir = gcc_installation_line
        .expect("Could not find GCC installation directory")
        .rsplit_once(" ")
        .expect("Could not remove output description")
        .1
        .to_owned()
        + "/include";

    // Generate flutter rust bindings
    let generation_result = Command::new("flutter_rust_bridge_codegen")
        .args(&["-r", "./src/api.rs", "-d", "../lib/bridge_generated.dart"])
        .env("CPATH", gcc_include_dir)
        .env("RUST_BACKTRACE", "1")
        .output()
        .expect("Failed to execute code generation command");

    if !generation_result.status.success() {
        let error_message = String::from_utf8_lossy(&generation_result.stderr);
        eprintln!("Code generation failed: {}", error_message);
        exit(1);
    }

    // Generate diesel schema
    let diesel_output = Command::new("diesel")
        .arg("setup")
        .output()
        .expect("Failed to execute schema generation command");
    if !diesel_output.status.success() {
        let error_message = String::from_utf8_lossy(&diesel_output.stderr);
        eprintln!("Schema generation failed: {}", error_message);
        exit(1);
    }
}
