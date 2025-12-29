use std::{
    ffi::OsStr,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use clap::Parser;
use xsd_parser::{
    Config,
    config::{OptimizerFlags, Schema},
    generate,
};

#[derive(clap::Parser)]
#[command(version, about, long_about=None)]
struct Args {
    /// Path to put generated rust files into
    #[arg(short, long)]
    output_folder: String,
}

fn write_to_file(path: PathBuf, content: String) -> bool {
    let mut output_file = std::fs::File::create(&path).unwrap();

    let write_result = output_file.write_all(content.as_bytes());

    if write_result.is_ok() {
        true
    } else {
        println!(
            "Could not write to '{}' due to '{}'",
            path.to_str().get_or_insert("could not convert path"),
            write_result
                .err()
                .map_or_else(|| "unknown error".to_owned(), |e| e.to_string())
        );

        false
    }
}

fn format_rust(content: String) -> String {
    let mut format_command = Command::new("rustfmt")
        .arg("--emit")
        .arg("stdout")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap(); // FIXME Handle error

    let stdin = format_command
        .stdin
        .as_mut()
        .ok_or("failed to open stdin")
        .unwrap(); // FIXME Handle error
    stdin.write_all(content.as_bytes()).unwrap(); // FIXME Handle error

    let formatted_output = format_command.wait_with_output().unwrap(); // FIXME Handle error

    assert!(
        formatted_output.status.success(),
        "Formatting command failed with '{}'",
        String::from_utf8_lossy(&formatted_output.stderr)
    );

    String::from_utf8(formatted_output.stdout).unwrap() // FIXME Handle error
}

fn main() {
    let args = Args::parse();

    let schema_path = Path::new("./schemas");
    assert!(schema_path.is_dir());

    let read_dir_result = std::fs::read_dir(schema_path);

    if read_dir_result.is_ok() {
        let xsd_schema_paths: Vec<PathBuf> = read_dir_result
            .unwrap()
            .filter(Result::is_ok)
            .map(Result::unwrap)
            .map(|dir_entry| dir_entry.path())
            .filter(|path| path.extension() == Some(OsStr::new("xsd")))
            .collect();

        let mut parser_config = Config::default()
            .with_derive(vec!["Debug", "serde::Serialize"])
            .with_optimizer_flags(OptimizerFlags::SERDE)
            .with_quick_xml_serialize();

        let output_folder = Path::new(&args.output_folder);
        let mut generated_files: Vec<String> = vec![];

        for path in xsd_schema_paths {
            parser_config.parser.schemas = vec![Schema::file(&path)];

            let token_stream =
                generate(parser_config.clone()).expect("Failed to generate Rust code");
            let content = token_stream.to_string();
            let formatted_content = format_rust(content);

            let path_with_rs_extension = path.with_extension("rs");
            let output_file_name_with_dots = path_with_rs_extension
                .file_name()
                .unwrap()
                .to_str()
                .unwrap();
            let num_dots = output_file_name_with_dots.matches(".").count();
            let output_file_name = output_file_name_with_dots.replacen(".", "_", num_dots - 1);
            let output_file_path = output_folder.join(&output_file_name);

            assert!(write_to_file(output_file_path, formatted_content));
            generated_files.push(output_file_name);
        }

        let output_file_path = output_folder.join("mod.rs");
        let content = generated_files
            .iter()
            .map(|file_name| format!("pub mod {};", file_name.strip_suffix(".rs").unwrap()))
            .fold("".to_owned(), |current_content, next_content| {
                format!("{}\n{}", current_content, next_content)
            });

        assert!(write_to_file(output_file_path, format_rust(content)));
    }
}
