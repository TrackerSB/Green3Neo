set dotenv-load := true
set dotenv-required := true

workspace_folder := "."
tasks_folder := workspace_folder + "/tasks"
tasks_venv_folder := tasks_folder + "/.venv"
backend_dir := workspace_folder + "/backend"
frb_dart_output_dir := workspace_folder + "/lib/backend"
llvmPath := `clang -v 2>&1 | grep 'Selected GCC installation' | rev | cut -d' ' -f1 | rev`
llvmIncludeDir := llvmPath + "/include"
venv_python := tasks_venv_folder + "/bin/python"

default:
    @just --list

[confirm]
clean:
    git clean -Xfd

_tasks-create-venv:
    python -m venv {{ tasks_venv_folder }}
    {{ venv_python }} -m pip install -r {{ tasks_folder }}/requirements.txt

database-start-postgresql:
    sudo systemctl start postgresql

database-populate-tables: _tasks-create-venv
    {{ venv_python }} {{ tasks_folder }}/populate_db_tables.py

database-create-tables: _tasks-create-venv && database-populate-tables
    {{ venv_python }} {{ tasks_folder }}/create_db_tables.py

database-drop-tables: _tasks-create-venv
    {{ venv_python }} {{ tasks_folder }}/delete_db_tables.py

database-recreate-tables: database-drop-tables database-create-tables

diesel-setup:
    cd {{ backend_dir }} && diesel setup

diesel-generate-schema:
    cd {{ backend_dir }} && diesel print-schema > src/schema.rs

diesel-generate-models:
    cd {{ backend_dir }} && diesel_ext --model --import-types diesel::Queryable --import-types diesel::Selectable --import-types diesel::Identifiable --import-types backend_macros::make_fields_non_final --import-types flutter_rust_bridge::frb --import-types crate::schema::* --derive Queryable,Selectable --add-table-name > src/models.rs
    git apply ./patches/models.rs.patch

# FIXME Verify that FRB versions in Cargo.toml, pubspec.yaml and the installed FRB codegen (locally and in Github
# Actions) correspond to each other
frb-generate:
    mkdir -p {{ frb_dart_output_dir }}
    flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root {{ backend_dir }} --dart-output {{ frb_dart_output_dir }}
    git apply ./patches/models.dart.patch

backend-build:
    cd {{ backend_dir }} && cargo build --release

flutter-generate-reflectable:
    dart run build_runner build --delete-conflicting-outputs

flutter-build:
    flutter build linux

build: diesel-setup diesel-generate-schema diesel-generate-models frb-generate backend-build flutter-generate-reflectable flutter-build

run: build
    flutter run

rebuild: clean build
