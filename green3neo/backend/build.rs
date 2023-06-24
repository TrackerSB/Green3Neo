use std::{process::Command, env};

fn main() {
    env::set_var("CPATH", "$(clang -v 2>&1 | grep \"Selected GCC installation\" | rev | cut -d' ' -f1 | rev)/include"); // FIXME Seems to have no effect
    
    // Execute the code generation command
    let output = Command::new("flutter_rust_bridge_codegen")
        .args(&["-r", "./src/api.rs", "-d", "../lib/bridge_generated.dart"])
        .output()
        .expect("Failed to execute code generation command.");

    if !output.status.success() {
        // Command failed, handle the error
        let error_message = String::from_utf8_lossy(&output.stderr);
        eprintln!("Code generation command failed: {}", error_message);
        std::process::exit(1);
    }
}
