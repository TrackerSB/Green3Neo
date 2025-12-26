use std::{
    ffi::OsStr,
    io::Write,
    path::{Path, PathBuf},
};

use clap::Parser;
use xsd_parser::{Config, config::Schema, generate};

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

        let mut parser_config = Config::default();
        let output_folder = Path::new(&args.output_folder);
        let mut generated_files: Vec<String> = vec![];

        for path in xsd_schema_paths {
            parser_config.parser.schemas = vec![Schema::file(&path)];

            let token_stream =
                generate(parser_config.clone()).expect("Failed to generate Rust code");
            // FIXME Apply formatting to generated tokens

            let path_with_rs_extension = path.with_extension("rs");
            let output_file_name_with_dots = path_with_rs_extension
                .file_name()
                .unwrap()
                .to_str()
                .unwrap();
            let num_dots = output_file_name_with_dots.matches(".").count();
            let output_file_name = output_file_name_with_dots.replacen(".", "_", num_dots - 1);

            let output_file_path = output_folder.join(&output_file_name);
            if write_to_file(output_file_path, token_stream.to_string()) {
                generated_files.push(output_file_name);
            }
        }

        let output_file_path = output_folder.join("mod.rs");
        let content = generated_files
            .iter()
            .map(|file_name| format!("pub mod {};", file_name.strip_suffix(".rs").unwrap()))
            .fold("".to_owned(), |current_content, next_content| {
                format!("{}\n{}", current_content, next_content)
            });

        assert!(write_to_file(output_file_path, content));
    }
}
