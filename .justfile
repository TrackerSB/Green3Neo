set dotenv-load := true
set dotenv-required := true

workspace_folder := "."

# Backend library paths
backend_dir := workspace_folder + "/backend"
backend_logging_dir := backend_dir + "/backend_logging"
sepa_xsd_to_rust_generator_dir := backend_dir + "/sepa_xsd_to_rust_generator"

# Backend interface library paths
backend_interface_dir := backend_dir + "/interface"
backend_api_dir := backend_interface_dir + "/backend_api"
frb_backend_api_output_dir := frontend_output_dir + "/backend_api"
database_api_dir := backend_interface_dir + "/database_api"
frb_database_api_output_dir := frontend_output_dir + "/database_api"
sepa_api_dir := backend_interface_dir + "/sepa_api"
frb_sepa_api_output_dir := frontend_output_dir + "/sepa_api"
rust_sepa_api_output_dir := sepa_api_dir + "/src/api/schemas"

# Frontend library paths
frontend_dir := workspace_folder + "/frontend"
frontend_output_dir := frontend_dir + "/lib"

# LLVM related paths
llvmPath := `clang -v 2>&1 | grep 'Selected GCC installation' | rev | cut -d' ' -f1 | rev`
llvmIncludeDir := llvmPath + "/include"

# Task paths
tasks_folder := workspace_folder + "/tasks"
tasks_venv_folder := tasks_folder + "/.venv"
venv_python := tasks_venv_folder + "/bin/python"

# Path to patches
patch_folder := workspace_folder + "/patches"

default:
    @just --list

[confirm]
clean:
    git clean -Xfd
    cd {{ backend_logging_dir }} && cargo clean
    cd {{ backend_api_dir }} && cargo clean
    cd {{ database_api_dir }} && cargo clean
    cd {{ sepa_api_dir }} && cargo clean

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
    cd {{ database_api_dir }} && diesel setup

diesel-generate-schema: diesel-setup
    cd {{ database_api_dir }} && diesel print-schema > src/schema.rs

diesel-generate-models: diesel-generate-schema
    cd {{ database_api_dir }} && diesel_ext --model --import-types diesel::Queryable --import-types diesel::Selectable --import-types diesel::Identifiable --import-types backend_macros::make_fields_non_final --import-types flutter_rust_bridge::frb --import-types crate::schema::* --derive Queryable,Selectable --add-table-name > src/api/models.rs
    git apply {{ patch_folder }}/backend/interface/database_api/api/models.rs.patch

sepa-generate-schemas:
    mkdir -p {{ rust_sepa_api_output_dir }}
    cd {{ sepa_xsd_to_rust_generator_dir }} && cargo run --release -- --output-folder ../../{{ rust_sepa_api_output_dir }}

# FIXME Verify that FRB versions in Cargo.toml, pubspec.yaml and the installed FRB codegen (locally and in Github
# Actions) correspond to each other
frb-generate: diesel-generate-models sepa-generate-schemas
    mkdir -p {{ frb_backend_api_output_dir }}
    flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root {{ backend_api_dir }} --dart-output {{ frb_backend_api_output_dir }} --stop-on-error

    mkdir -p {{ frb_database_api_output_dir }}
    flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root {{ database_api_dir }} --dart-output {{ frb_database_api_output_dir }} --stop-on-error
    git apply {{ patch_folder }}/frontend/database_api/api/models.dart.patch
    - git apply {{ patch_folder }}/frontend/database_api/frb_generated.dart.patch
    - git apply {{ patch_folder }}/frontend/database_api/frb_generated.dart.alternative.patch

    mkdir -p {{ frb_sepa_api_output_dir }}
    flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root {{ sepa_api_dir }} --dart-output {{ frb_sepa_api_output_dir }} --stop-on-error

backend-build: frb-generate
    cd {{ backend_api_dir }} && cargo build --release
    cd {{ database_api_dir }} && cargo build --release
    cd {{ sepa_api_dir }} && cargo build --release

frontend-generate-reflectable: frb-generate
    cd {{ frontend_dir }} && dart run build_runner build --delete-conflicting-outputs

frontend-build: frontend-generate-reflectable
    cd {{ frontend_dir }} && flutter build linux

build: backend-build frontend-build

run: build
    cd {{ frontend_dir }} && flutter run

rebuild: clean build

test-backend-unittets: frb-generate
    cd {{ backend_logging_dir }} && cargo test -- --nocapture
    cd {{ backend_api_dir }} && cargo test -- --nocapture
    cd {{ database_api_dir }} && cargo test -- --nocapture
    cd {{ sepa_api_dir }} && cargo test -- --nocapture

test-frontend-widget-tests: build
    cd {{ frontend_dir }} && flutter test

test: test-backend-unittets test-frontend-widget-tests
