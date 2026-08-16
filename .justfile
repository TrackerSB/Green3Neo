set dotenv-load
set dotenv-required
# Load environment variables if none loaded but do not override variables e.g. set by Github actions
set dotenv-override := false

set shell := ["bash", "-euo", "pipefail", "-c"]

# FIXME Make workspace folder absolute (maybe using git to find git root?)
workspace_dir := "."

# Backend library paths
backend_dir := workspace_dir + "/backend"
backend_logging_dir := backend_dir + "/backend_logging"
backend_testing_dir := backend_dir + "/backend_testing"
sepa_xsd_to_rust_generator_dir := backend_dir + "/sepa_xsd_to_rust_generator"

# Backend interface library paths
backend_interface_dir := backend_dir + "/interface"

backend_api_dir := backend_interface_dir + "/backend_api"
frb_backend_api_output_dir := frontend_interface_dir + "/backend_api"

database_api_dir := backend_interface_dir + "/database_api"
frb_database_api_output_dir := frontend_interface_dir + "/database_api"

sepa_api_dir := backend_interface_dir + "/sepa_api"
frb_sepa_api_output_dir := frontend_interface_dir + "/sepa_api"

rust_sepa_api_output_dir := sepa_api_dir + "/src/schemas"

# Frontend library paths
frontend_dir := workspace_dir + "/frontend"
frontend_interface_dir := frontend_dir + "/lib/interface"

# LLVM related paths
llvmPath := `clang -v 2>&1 | grep 'Selected GCC installation' | rev | cut -d' ' -f1 | rev`
llvmIncludeDir := llvmPath + "/include"

# Task paths
tasks_folder := workspace_dir + "/tasks"
tasks_venv_folder := tasks_folder + "/.venv"
venv_python := tasks_venv_folder + "/bin/python"

# Path to patches
patch_folder := workspace_dir + "/patches"

# All API features (build variants)
all_backend_api_features := "mysql, postgres"
all_database_api_features := "mysql, postgres"

default:
    @just --list

[confirm]
clean:
    git clean -Xfd
    cd {{ backend_dir }} && cargo clean

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

# FIXME Verify whether exactly one of the alternative patches was applied
# FIXME Apply formatting stabilizing which patch works
diesel-generate-models: diesel-generate-schema
    cd {{ database_api_dir }} && diesel_ext --model --import-types diesel::Queryable --import-types diesel::QueryableByName --import-types diesel::Selectable --import-types diesel::Identifiable --import-types backend_macros::make_fields_non_final --import-types backend_macros::JsonFieldConversionGenerator --import-types serde::Serialize --import-types serde::Deserialize --import-types flutter_rust_bridge::frb --import-types crate::json_field_conversion::JsonFieldConversion --import-types crate::schema::* --derive Queryable,QueryableByName,Selectable,Serialize,Deserialize,JsonFieldConversionGenerator --add-table-name > src/api/models.rs
    git apply {{ patch_folder }}/backend/interface/database_api/api/models.rs.patch

sepa-generate-schemas:
    mkdir -p {{ rust_sepa_api_output_dir }}
    cd {{ sepa_xsd_to_rust_generator_dir }} && cargo run --release -- --output-folder ../../{{ rust_sepa_api_output_dir }}

# FIXME Verify that FRB versions in Cargo.toml, pubspec.yaml and the installed FRB codegen (locally and in Github
# Actions) correspond to each other
# FIXME Verify whether exactly one of the alternative patches was applied
# FIXME Apply formatting stabilizing which patch works
frb-generate backendApiFeatures databaseApiFeatures: diesel-generate-models sepa-generate-schemas
    mkdir -p {{ frb_backend_api_output_dir }}
    cd {{ frontend_dir }} && flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --rust-features "{{ backendApiFeatures }}" --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root ../{{ backend_api_dir }} --dart-output ../{{ frb_backend_api_output_dir }} --stop-on-error

    mkdir -p {{ frb_database_api_output_dir }}
    cd {{ frontend_dir }} && flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --rust-features "{{ databaseApiFeatures }}" --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root ../{{ database_api_dir }} --dart-output ../{{ frb_database_api_output_dir }} --stop-on-error
    git apply {{ patch_folder }}/frontend/interface/database_api/api/models.dart.patch \
      || git apply {{ patch_folder }}/frontend/interface/database_api/api/models.dart.alternative.patch

    mkdir -p {{ frb_sepa_api_output_dir }}
    cd {{ frontend_dir }} && flutter_rust_bridge_codegen generate --no-web --no-add-mod-to-lib --llvm-path {{ llvmIncludeDir }} --rust-input "crate::api" --rust-root ../{{ sepa_api_dir }} --dart-output ../{{ frb_sepa_api_output_dir }} --stop-on-error --rust-preamble "use chrono::NaiveDate;use chrono::NaiveDateTime;"

backend-api-build backendApiFeatures databaseApiFeatures:
    just frb-generate "{{ backendApiFeatures }}" "{{ databaseApiFeatures }}"
    cd {{ backend_dir }} && cargo build --release -p backend_api -p database_api -p sepa_api --features "{{ backendApiFeatures }} {{ databaseApiFeatures }}"

backend-build:
    just backend-api-build "{{ all_backend_api_features }}" "{{ all_database_api_features }}"

frontend-generate-reflectable: backend-build
    cd {{ frontend_dir }} && fvm dart run build_runner build

frontend-build: frontend-generate-reflectable
    cd {{ frontend_dir }} && fvm flutter build linux

build: backend-build frontend-build

run: build
    cd {{ frontend_dir }} && fvm flutter run

rebuild: clean build

backend-test:
    just backend-api-build "$BUILD_DB_PROTOCOL" "$BUILD_DB_PROTOCOL"
    cd {{ backend_dir }} && cargo nextest run --config-file .nextest.toml --no-default-features --features "$BUILD_DB_PROTOCOL"

frontend-test: build
    cd {{ frontend_dir }} && fvm flutter test --machine | tojunit > build/junit.xml

test: backend-test frontend-test
