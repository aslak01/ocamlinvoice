use base64::{engine::general_purpose, Engine as _};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
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

// Database functions
fn get_database_path() -> Result<std::path::PathBuf, String> {
    let ocaml_backend = get_ocaml_backend_path()?;
    Ok(ocaml_backend.join("invoices.db"))
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

// Read a single file
#[tauri::command]
fn read_file(file_path: String) -> Result<String, String> {
    let config_path = get_config_path(&file_path);
    fs::read_to_string(&config_path)
        .map_err(|e| format!("Failed to read file {}: {}", config_path, e))
}

// Write a single file
#[tauri::command]
fn write_file(file_path: String, content: String) -> Result<(), String> {
    let config_path = get_config_path(&file_path);

    // Ensure the config directory exists
    if let Some(parent) = Path::new(&config_path).parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
    }

    fs::write(&config_path, content)
        .map_err(|e| format!("Failed to write file {}: {}", config_path, e))
}

// Read all config files
#[tauri::command]
fn read_all_files() -> Result<InvoiceFiles, String> {
    Ok(InvoiceFiles {
        sender: read_file("sender.txt".to_string())?,
        bankdetails: read_file("bankdetails.txt".to_string())?,
        description: read_file("description.txt".to_string()).unwrap_or_default(),
        amount: read_file("amount.txt".to_string()).unwrap_or_default(),
        recipients: read_file("recipients.txt".to_string())?,
    })
}

// Save invoice details (description and amount)
#[tauri::command]
fn save_invoice_details(description: String, amount: String) -> Result<(), String> {
    write_file("description.txt".to_string(), description)?;
    write_file("amount.txt".to_string(), amount)?;
    Ok(())
}

fn get_tauri_app_path() -> Result<std::path::PathBuf, String> {
    let current_dir =
        std::env::current_dir().map_err(|e| format!("Failed to get current directory: {}", e))?;

    // Check if we're in src-tauri subdirectory
    if current_dir.file_name() == Some("src-tauri".as_ref()) {
        // We're in src-tauri, go up one level to tauri-gui
        Ok(current_dir.parent().unwrap().to_path_buf())
    } else if current_dir.file_name() == Some("tauri-gui".as_ref()) {
        // We're already in tauri-gui
        Ok(current_dir)
    } else {
        // Check if we can find tauri-gui directory
        let tauri_gui_path = current_dir.join("tauri-gui");
        if tauri_gui_path.exists() {
            Ok(tauri_gui_path)
        } else {
            Err("Could not find tauri-gui directory".to_string())
        }
    }
}

fn get_ocaml_backend_path() -> Result<std::path::PathBuf, String> {
    let tauri_app = get_tauri_app_path()?;
    let ocaml_backend = tauri_app.join("ocaml-backend");

    if ocaml_backend.exists() {
        Ok(ocaml_backend)
    } else {
        Err("Could not find ocaml-backend directory".to_string())
    }
}

// Run invoice generation
#[tauri::command]
fn generate_invoices(dry_run: bool) -> Result<String, String> {
    let ocaml_backend =
        get_ocaml_backend_path().map_err(|e| format!("Failed to find OCaml backend: {}", e))?;

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
        .map_err(|e| format!("Failed to execute command: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

fn get_config_path(filename: &str) -> String {
    let ocaml_backend =
        get_ocaml_backend_path().unwrap_or_else(|_| std::env::current_dir().unwrap());

    ocaml_backend
        .join("config")
        .join(filename)
        .to_string_lossy()
        .to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            read_file,
            write_file,
            read_all_files,
            save_invoice_details,
            generate_invoices,
            get_all_invoices,
            get_invoice_by_id
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
