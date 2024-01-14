use std::process::{exit, Command};

fn main() {
    println!("cargo:warning=Find GCC include dir candidates");
    let clang_output_child = Command::new("clang")
        .args(&["-v"])
        .output()
        .expect("Could not collect clang output");

    if !clang_output_child.status.success() {
        println!("cargo:warning=Could not receive clang output");
        exit(1);
    }

    println!("cargo:warning=Find selected GCC installation");
    let clang_output = String::from_utf8_lossy(&clang_output_child.stderr);
    let mut gcc_installation_lines = clang_output
        .lines()
        .filter(|&line| line.starts_with("Selected GCC installation"));

    let gcc_installation_line = gcc_installation_lines.next();

    let additional_gcc_installation_line = gcc_installation_lines.next();
    if additional_gcc_installation_line.is_some() {
        println!("cargo:warning=The GCC installation directory is ambigous");
        exit(1);
    }

    println!("cargo:warning=Determine GCC installation include dir");
    let gcc_include_dir = gcc_installation_line
        .expect("Could not find GCC installation directory")
        .rsplit_once(" ")
        .expect("Could not remove output description")
        .1
        .to_owned()
        + "/include";

    println!("cargo:warning=Generate flutter rust bindings");
    let frb_generation_result = Command::new("flutter_rust_bridge_codegen")
        .args(&["generate", "-r", "./src/api.rs", "-d", "../lib/"])
        .env("CPATH", gcc_include_dir)
        .env("RUST_BACKTRACE", "full")
        .output()
        .expect("Failed to execute FRB code generation command");

    if !frb_generation_result.status.success() {
        let error_message = String::from_utf8_lossy(&frb_generation_result.stderr);
        println!("cargo:warning=FRB code generation failed: {}", error_message);
        exit(1);
    }
}
