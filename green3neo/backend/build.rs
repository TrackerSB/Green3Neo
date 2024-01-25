use dotenv::dotenv;
use std::fs::File;
use std::io::Write;
use std::process::{exit, Command};

fn main() {
    println!("cargo:warning=Load local environment variables");
    dotenv().ok();

    println!("cargo:warning=Setup diesel");
    let diesel_setup_output = Command::new("diesel")
        .arg("setup")
        .output()
        .expect("Failed to set up diesel");
    if !diesel_setup_output.status.success() {
        let error_message = String::from_utf8_lossy(&diesel_setup_output.stderr);
        println!("cargo:warning=Schema setup failed: {}", error_message);
        exit(1);
    }

    println!("cargo:warning=Generate diesel schema");
    let diesel_schema_output = Command::new("diesel")
        .arg("print-schema")
        .output()
        .expect("Failed to execute schema generation command");
    if !diesel_schema_output.status.success() {
        let error_message = String::from_utf8_lossy(&diesel_schema_output.stderr);
        println!("cargo:warning=Schema generation failed: {}", error_message);
        exit(1);
    }

    let schema_file_path = "src/schema.rs"; // FIXME Determine from diesel.toml
    let file_creation_result = File::create(schema_file_path);
    if file_creation_result.is_err() {
        println!("Could not create file {} for schema", schema_file_path);
        exit(1);
    }

    if file_creation_result
        .unwrap()
        .write_all(&diesel_schema_output.stdout)
        .is_err()
    {
        println!("Could not write schema to {}", schema_file_path);
        exit(1);
    }

    println!("cargo:warning=Generate diesel models");
    let diesel_models_output = Command::new("diesel_ext")
        /* NOTE 2024-01-14:  The additional imports are added to the model output whereas the additional types in the
         * diesel config are added to the schema output
         */
        .args([
            "--model",
            "--import-types",
            "diesel::Queryable",
            "--import-types",
            "diesel::Identifiable",
            "--import-types",
            "crate::schema::*",
            "--add-table-name"
        ])
        .output()
        .expect("Failed to execute model generation command");
    if !diesel_models_output.status.success() {
        let error_message = String::from_utf8_lossy(&diesel_models_output.stderr);
        println!("cargo:warning=Model generation failed: {}", error_message);
        exit(1);
    }

    let models_file_path = "src/models.rs"; // FIXME Determine from somewhere like diesel.toml?
    let file_creation_result = File::create(models_file_path);
    if file_creation_result.is_err() {
        println!("Could not create file {} for models", models_file_path);
        exit(1);
    }

    if file_creation_result
        .unwrap()
        .write_all(&diesel_models_output.stdout)
        .is_err()
    {
        println!("Could not write models to {}", models_file_path);
        exit(1);
    }

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
        .args(&[
            "generate",
            "--no-web",
            "--no-add-mod-to-lib",
            "-r",
            "./src/api.rs",
            "-d",
            "../lib/",
            "--extra-headers",
            "foo",
        ])
        .env("CPATH", gcc_include_dir)
        .env("RUST_BACKTRACE", "full")
        .output()
        .expect("Failed to execute FRB code generation command");

    if !frb_generation_result.status.success() {
        let error_message = String::from_utf8_lossy(&frb_generation_result.stderr);
        println!(
            "cargo:warning=FRB code generation failed: {}",
            error_message
        );
        exit(1);
    }

    println!("cargo:warning=Generate flutter reflectable code");
    let reflectable_generation_result = Command::new("flutter")
        .args(&[
              "pub",
              "run",
              "build_runner",
              "build"
        ])
        .output()
        .expect("Failed to execute reflectable code generation command");

    if !reflectable_generation_result.status.success() {
        let error_message = String::from_utf8_lossy(&reflectable_generation_result.stderr);
        println!(
            "cargo:warning=Reflectable code generation failed: {}",
            error_message
        );
        exit(1);
    }
}
