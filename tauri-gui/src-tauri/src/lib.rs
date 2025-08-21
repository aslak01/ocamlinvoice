use base64::{engine::general_purpose, Engine as _};
use dirs;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Serialize, Deserialize)]
struct FileData {
    content: String,
    amount: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct InvoiceFiles {
    sender: String,
    bankdetails: String,
    description: String,
    amount: String,
    recipients: String,
}

#[derive(Serialize, Deserialize)]
struct InvoiceRecord {
    id: i32,
    invoice_number: String,
    service: String,
    invoice_date: String,
    due_date: String,
    vat_enabled: bool,
    vat_rate: i32,
    created_at: String,
    pdf_base64: String,
}

#[derive(Serialize, Deserialize)]
struct AppSettings {
    output_directory: String,
    config_directory: String,
}

// Directory management functions
fn get_app_data_dir() -> Result<PathBuf, String> {
    let app_data = dirs::data_dir()
        .ok_or("Could not determine data directory")?
        .join("InvoiceGenerator");

    // Ensure the directory exists
    fs::create_dir_all(&app_data)
        .map_err(|e| format!("Failed to create app data directory: {}", e))?;

    Ok(app_data)
}

fn get_default_output_dir() -> Result<PathBuf, String> {
    let documents = dirs::document_dir()
        .ok_or("Could not determine documents directory")?
        .join("InvoiceGenerator");

    // Ensure the directory exists
    fs::create_dir_all(&documents)
        .map_err(|e| format!("Failed to create documents directory: {}", e))?;

    Ok(documents)
}

fn get_config_dir() -> Result<PathBuf, String> {
    let config_dir = get_app_data_dir()?.join("config");

    // Ensure the directory exists
    fs::create_dir_all(&config_dir)
        .map_err(|e| format!("Failed to create config directory: {}", e))?;

    Ok(config_dir)
}

fn get_settings_path() -> Result<PathBuf, String> {
    let app_data = get_app_data_dir()?;
    Ok(app_data.join("settings.json"))
}

// Settings management
#[tauri::command]
fn get_app_settings() -> Result<AppSettings, String> {
    let settings_path = get_settings_path()?;

    if settings_path.exists() {
        let content = fs::read_to_string(&settings_path)
            .map_err(|e| format!("Failed to read settings: {}", e))?;

        serde_json::from_str(&content).map_err(|e| format!("Failed to parse settings: {}", e))
    } else {
        // Create default settings
        let default_output = get_default_output_dir()?;
        let default_config = get_config_dir()?;

        let settings = AppSettings {
            output_directory: default_output.to_string_lossy().to_string(),
            config_directory: default_config.to_string_lossy().to_string(),
        };

        // Save default settings
        save_app_settings(settings.clone())?;
        Ok(settings)
    }
}

#[tauri::command]
fn save_app_settings(settings: AppSettings) -> Result<(), String> {
    let settings_path = get_settings_path()?;

    // Ensure output directory exists
    fs::create_dir_all(&settings.output_directory)
        .map_err(|e| format!("Failed to create output directory: {}", e))?;

    // Ensure config directory exists
    fs::create_dir_all(&settings.config_directory)
        .map_err(|e| format!("Failed to create config directory: {}", e))?;

    let content = serde_json::to_string_pretty(&settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    fs::write(settings_path, content).map_err(|e| format!("Failed to save settings: {}", e))
}

// Database functions
fn get_database_path() -> Result<PathBuf, String> {
    let app_data = get_app_data_dir()?;
    Ok(app_data.join("invoices.db"))
}

fn connect_database() -> Result<Connection, String> {
    let db_path = get_database_path()?;
    Connection::open(db_path).map_err(|e| format!("Failed to open database: {}", e))
}

// Get all invoices from database
#[tauri::command]
fn get_all_invoices() -> Result<Vec<InvoiceRecord>, String> {
    let conn = connect_database()?;

    let mut stmt = conn
        .prepare(
            "SELECT id, invoice_number, service, invoice_date, due_date, 
                vat_enabled, vat_rate, created_at, pdf_content 
         FROM invoices 
         ORDER BY created_at DESC",
        )
        .map_err(|e| format!("Failed to prepare query: {}", e))?;

    let invoice_iter = stmt
        .query_map([], |row| {
            let pdf_content: Vec<u8> = row.get(8)?;
            let pdf_base64 = general_purpose::STANDARD.encode(&pdf_content);

            Ok(InvoiceRecord {
                id: row.get(0)?,
                invoice_number: row.get(1)?,
                service: row.get(2)?,
                invoice_date: row.get(3)?,
                due_date: row.get(4)?,
                vat_enabled: row.get::<_, i32>(5)? != 0,
                vat_rate: row.get(6)?,
                created_at: row.get(7)?,
                pdf_base64,
            })
        })
        .map_err(|e| format!("Failed to execute query: {}", e))?;

    let mut invoices = Vec::new();
    for invoice in invoice_iter {
        invoices.push(invoice.map_err(|e| format!("Failed to parse row: {}", e))?);
    }

    Ok(invoices)
}

// Get a specific invoice by ID
#[tauri::command]
fn get_invoice_by_id(id: i32) -> Result<InvoiceRecord, String> {
    let conn = connect_database()?;

    let mut stmt = conn
        .prepare(
            "SELECT id, invoice_number, service, invoice_date, due_date, 
                vat_enabled, vat_rate, created_at, pdf_content 
         FROM invoices 
         WHERE id = ?",
        )
        .map_err(|e| format!("Failed to prepare query: {}", e))?;

    let invoice = stmt
        .query_row([id], |row| {
            let pdf_content: Vec<u8> = row.get(8)?;
            let pdf_base64 = general_purpose::STANDARD.encode(&pdf_content);

            Ok(InvoiceRecord {
                id: row.get(0)?,
                invoice_number: row.get(1)?,
                service: row.get(2)?,
                invoice_date: row.get(3)?,
                due_date: row.get(4)?,
                vat_enabled: row.get::<_, i32>(5)? != 0,
                vat_rate: row.get(6)?,
                created_at: row.get(7)?,
                pdf_base64,
            })
        })
        .map_err(|e| format!("Failed to get invoice: {}", e))?;

    Ok(invoice)
}

// File operations with user-configurable directories
#[tauri::command]
fn read_file(file_path: String) -> Result<String, String> {
    let settings = get_app_settings()?;
    let config_path = Path::new(&settings.config_directory).join(&file_path);

    if config_path.exists() {
        fs::read_to_string(&config_path)
            .map_err(|e| format!("Failed to read file {}: {}", config_path.display(), e))
    } else {
        // Return empty string for non-existent files (allows for initial setup)
        Ok(String::new())
    }
}

#[tauri::command]
fn write_file(file_path: String, content: String) -> Result<(), String> {
    let settings = get_app_settings()?;
    let config_path = Path::new(&settings.config_directory).join(&file_path);

    // Ensure the config directory exists
    if let Some(parent) = config_path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
    }

    fs::write(&config_path, content)
        .map_err(|e| format!("Failed to write file {}: {}", config_path.display(), e))
}

// Read all config files
#[tauri::command]
fn read_all_files() -> Result<InvoiceFiles, String> {
    Ok(InvoiceFiles {
        sender: read_file("sender.txt".to_string()).unwrap_or_default(),
        bankdetails: read_file("bankdetails.txt".to_string()).unwrap_or_default(),
        description: read_file("description.txt".to_string()).unwrap_or_default(),
        amount: read_file("amount.txt".to_string()).unwrap_or_default(),
        recipients: read_file("recipients.txt".to_string()).unwrap_or_default(),
    })
}

// Save invoice details (description and amount)
#[tauri::command]
fn save_invoice_details(description: String, amount: String) -> Result<(), String> {
    write_file("description.txt".to_string(), description)?;
    write_file("amount.txt".to_string(), amount)?;
    Ok(())
}

// Get the bundled OCaml backend path
fn get_bundled_ocaml_backend() -> Result<PathBuf, String> {
    // In development, look for the ocaml-backend directory
    let current_exe =
        std::env::current_exe().map_err(|e| format!("Failed to get current executable: {}", e))?;

    let exe_dir = current_exe
        .parent()
        .ok_or("Failed to get executable directory")?;

    // Try different possible locations
    let possible_paths = [
        // Development mode (when running from tauri-gui/src-tauri)
        exe_dir.join("../../../ocaml-backend"),
        exe_dir.join("../../ocaml-backend"),
        exe_dir.join("../ocaml-backend"),
        // Production mode (bundled)
        exe_dir.join("ocaml-backend"),
        // macOS app bundle
        exe_dir.join("../Resources/ocaml-backend"),
    ];

    for path in possible_paths {
        if path.exists() && path.join("src").exists() {
            return Ok(path
                .canonicalize()
                .map_err(|e| format!("Failed to canonicalize path: {}", e))?);
        }
    }

    Err(
        "Could not find OCaml backend directory. Make sure the application is properly installed."
            .to_string(),
    )
}

// Copy config files to OCaml backend working directory
fn setup_ocaml_environment() -> Result<PathBuf, String> {
    let settings = get_app_settings()?;
    let ocaml_backend = get_bundled_ocaml_backend()?;
    let ocaml_config = ocaml_backend.join("config");

    // Ensure OCaml config directory exists
    fs::create_dir_all(&ocaml_config)
        .map_err(|e| format!("Failed to create OCaml config directory: {}", e))?;

    // Copy config files from user config to OCaml config
    let config_files = [
        "sender.txt",
        "bankdetails.txt",
        "description.txt",
        "amount.txt",
        "recipients.txt",
    ];

    for file in config_files {
        let user_config_path = Path::new(&settings.config_directory).join(file);
        let ocaml_config_path = ocaml_config.join(file);

        if user_config_path.exists() {
            fs::copy(&user_config_path, &ocaml_config_path)
                .map_err(|e| format!("Failed to copy {} to OCaml config: {}", file, e))?;
        } else {
            // Create empty file if it doesn't exist
            fs::write(&ocaml_config_path, "")
                .map_err(|e| format!("Failed to create empty {} in OCaml config: {}", file, e))?;
        }
    }

    Ok(ocaml_backend)
}

// Copy generated PDFs back to user output directory
fn copy_generated_pdfs(ocaml_backend: &Path) -> Result<Vec<String>, String> {
    let settings = get_app_settings()?;
    let ocaml_out = ocaml_backend.join("out");
    let user_output = Path::new(&settings.output_directory);

    if !ocaml_out.exists() {
        return Ok(Vec::new());
    }

    let mut copied_files = Vec::new();

    // Read the out directory and copy all PDF files
    let entries = fs::read_dir(&ocaml_out)
        .map_err(|e| format!("Failed to read OCaml out directory: {}", e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("pdf") {
            let filename = path
                .file_name()
                .ok_or("Failed to get filename")?
                .to_str()
                .ok_or("Invalid filename")?;

            let target_path = user_output.join(filename);

            fs::copy(&path, &target_path)
                .map_err(|e| format!("Failed to copy {} to output directory: {}", filename, e))?;

            copied_files.push(filename.to_string());
        }
    }

    Ok(copied_files)
}

// Run invoice generation with proper environment setup
#[tauri::command]
fn generate_invoices(dry_run: bool) -> Result<String, String> {
    // Setup OCaml environment and copy config files
    let ocaml_backend = setup_ocaml_environment()?;

    // Build the OCaml project first
    let mut build_cmd = Command::new("dune");
    build_cmd.current_dir(&ocaml_backend);
    build_cmd.arg("build");

    let build_output = build_cmd
        .output()
        .map_err(|e| format!("Failed to execute dune build: {}", e))?;

    if !build_output.status.success() {
        return Err(format!(
            "Dune build failed: {}",
            String::from_utf8_lossy(&build_output.stderr)
        ));
    }

    // Run the invoice generation
    let mut cmd = Command::new("dune");
    cmd.current_dir(&ocaml_backend);
    cmd.arg("exec");
    cmd.arg("src/main.exe");

    if dry_run {
        cmd.arg("--");
        cmd.arg("-dry");
    }

    let output = cmd
        .output()
        .map_err(|e| format!("Failed to execute invoice generation: {}", e))?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();

        // Copy generated PDFs to user output directory
        let copied_files = copy_generated_pdfs(&ocaml_backend)?;

        let mut result = stdout;
        if !copied_files.is_empty() {
            result.push_str(&format!("\n\nGenerated PDFs copied to output directory:\n"));
            for file in copied_files {
                result.push_str(&format!("- {}\n", file));
            }
        }

        Ok(result)
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            read_file,
            write_file,
            read_all_files,
            save_invoice_details,
            generate_invoices,
            get_all_invoices,
            get_invoice_by_id,
            get_app_settings,
            save_app_settings
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
