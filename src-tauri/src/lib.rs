use base64::{engine::general_purpose, Engine as _};
use dirs;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

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

#[derive(Serialize, Deserialize, Clone)]
struct AppSettings {
    output_directory: String,
}

// Directory management functions
fn get_app_data_dir() -> Result<PathBuf, String> {
    let app_data = dirs::data_dir()
        .ok_or("Could not determine data directory")?
        .join("InvoiceSplitter");

    // Ensure the directory exists
    fs::create_dir_all(&app_data)
        .map_err(|e| format!("Failed to create app data directory: {}", e))?;

    Ok(app_data)
}

fn get_default_output_dir() -> Result<PathBuf, String> {
    let documents = dirs::document_dir()
        .ok_or("Could not determine documents directory")?
        .join("InvoiceSplitter");

    // Ensure the directory exists
    fs::create_dir_all(&documents)
        .map_err(|e| format!("Failed to create documents directory: {}", e))?;

    Ok(documents)
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

        let settings = AppSettings {
            output_directory: default_output.to_string_lossy().to_string(),
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

    let content = serde_json::to_string_pretty(&settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    fs::write(settings_path, content).map_err(|e| format!("Failed to save settings: {}", e))
}

// Database functions
fn get_database_path() -> Result<PathBuf, String> {
    // Always use a consistent location in app data for shared access
    let app_data = get_app_data_dir()?;
    Ok(app_data.join("invoices.db"))
}

fn connect_database() -> Result<Connection, String> {
    let db_path = get_database_path()?;
    let conn = Connection::open(db_path).map_err(|e| format!("Failed to open database: {}", e))?;
    
    // Initialize the database schema
    init_database(&conn)?;
    
    Ok(conn)
}

fn init_database(conn: &Connection) -> Result<(), String> {
    // Only create the settings table - let OCaml backend handle its own tables
    conn.execute(
        "CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )",
        [],
    ).map_err(|e| format!("Failed to create settings table: {}", e))?;
    
    // Initialize example settings for first-time users
    let examples = [
        ("sender", "Your Company Name\nYour Address\nCity, Postal Code\nCountry"),
        ("bankdetails", "Bank Name: Your Bank\nAccount: 1234-56-78901\nIBAN: NO1234567890123456\nBIC: BANKNO22"),
        ("description", "Consulting services\nWeb development\nProject management"),
        ("amount", "5000.00"),
        ("recipients", "Client Company\nclient@example.com\nClient Address\nCity, Postal Code\n\nAnother Client\nanother@example.com\nAnother Address\nCity, Postal Code"),
        ("_app_initialized", "true"),
    ];
    
    for (key, example_value) in examples {
        conn.execute(
            "INSERT OR IGNORE INTO settings (key, value) VALUES (?1, ?2)",
            [key, example_value],
        ).map_err(|e| format!("Failed to insert example setting {}: {}", key, e))?;
    }
    
    Ok(())
}

// Get all invoices from database
#[tauri::command]
fn get_all_invoices() -> Result<Vec<InvoiceRecord>, String> {
    let conn = connect_database()?;

    // First check if the invoices table exists and has been properly initialized by OCaml backend
    let table_exists = conn
        .prepare("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='invoices'")
        .and_then(|mut stmt| stmt.query_row([], |row| row.get::<_, i32>(0)))
        .unwrap_or(0) > 0;
        
    if !table_exists {
        // No invoices table yet - return empty list
        return Ok(Vec::new());
    }
    
    // Check if table has the expected schema
    let has_locale = conn
        .prepare("PRAGMA table_info(invoices)")
        .and_then(|mut stmt| {
            let rows = stmt.query_map([], |row| {
                Ok(row.get::<_, String>(1)?) // column name
            })?;
            let columns: Vec<String> = rows.collect::<Result<Vec<_>, _>>()?;
            Ok(columns.contains(&"locale".to_string()))
        })
        .unwrap_or(false);
        
    if !has_locale {
        // Table exists but doesn't have expected schema - return empty list
        return Ok(Vec::new());
    }

    // Use the OCaml database schema
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
                vat_enabled: row.get::<_, bool>(5)?, // OCaml uses BOOLEAN not INTEGER
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

// Settings management functions
fn get_setting(key: &str) -> Result<Option<String>, String> {
    let conn = connect_database()?;
    
    let mut stmt = conn
        .prepare("SELECT value FROM settings WHERE key = ?")
        .map_err(|e| format!("Failed to prepare query: {}", e))?;
    
    match stmt.query_row([key], |row| Ok(row.get::<_, String>(0)?)) {
        Ok(value) => Ok(Some(value)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(format!("Failed to get setting: {}", e)),
    }
}

fn set_setting(key: &str, value: &str) -> Result<(), String> {
    let conn = connect_database()?;
    
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        [key, value],
    ).map_err(|e| format!("Failed to set setting: {}", e))?;
    
    Ok(())
}

#[tauri::command]
fn get_config_setting(key: String) -> Result<String, String> {
    get_setting(&key).map(|opt| opt.unwrap_or_default())
}

#[tauri::command]
fn set_config_setting(key: String, value: String) -> Result<(), String> {
    set_setting(&key, &value)
}

#[tauri::command]
fn is_first_run() -> Result<bool, String> {
    match get_setting("_app_initialized") {
        Ok(Some(_)) => Ok(false), // App has been initialized
        Ok(None) => Ok(true),     // First run
        Err(e) => Err(e),
    }
}

// Get a specific invoice by ID
#[tauri::command]
fn get_invoice_by_id(id: i32) -> Result<InvoiceRecord, String> {
    let conn = connect_database()?;

    // Check if the invoices table exists and is properly initialized
    let table_exists = conn
        .prepare("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='invoices'")
        .and_then(|mut stmt| stmt.query_row([], |row| row.get::<_, i32>(0)))
        .unwrap_or(0) > 0;
        
    if !table_exists {
        return Err("Invoice table not found".to_string());
    }

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
                vat_enabled: row.get::<_, bool>(5)?, // OCaml uses BOOLEAN not INTEGER
                vat_rate: row.get(6)?,
                created_at: row.get(7)?,
                pdf_base64,
            })
        })
        .map_err(|e| format!("Failed to get invoice: {}", e))?;

    Ok(invoice)
}

// Legacy file operations (now using database)
#[tauri::command]
fn read_file(file_path: String) -> Result<String, String> {
    // Map file names to setting keys
    let setting_key = match file_path.as_str() {
        "sender.txt" => "sender",
        "bankdetails.txt" => "bankdetails",
        "description.txt" => "description", 
        "amount.txt" => "amount",
        "recipients.txt" => "recipients",
        _ => return Ok(String::new()),
    };
    
    get_config_setting(setting_key.to_string())
}

#[tauri::command]
fn write_file(file_path: String, content: String) -> Result<(), String> {
    // Map file names to setting keys
    let setting_key = match file_path.as_str() {
        "sender.txt" => "sender",
        "bankdetails.txt" => "bankdetails",
        "description.txt" => "description",
        "amount.txt" => "amount",
        "recipients.txt" => "recipients",
        _ => return Err("Unknown config file".to_string()),
    };
    
    set_config_setting(setting_key.to_string(), content)
}

// Read all config files
#[tauri::command]
fn read_all_files() -> Result<InvoiceFiles, String> {
    Ok(InvoiceFiles {
        sender: get_config_setting("sender".to_string())?,
        bankdetails: get_config_setting("bankdetails".to_string())?,
        description: get_config_setting("description".to_string())?,
        amount: get_config_setting("amount".to_string())?,
        recipients: get_config_setting("recipients".to_string())?,
    })
}

// Save invoice details (description and amount)
#[tauri::command]
fn save_invoice_details(description: String, amount: String) -> Result<(), String> {
    set_config_setting("description".to_string(), description)?;
    set_config_setting("amount".to_string(), amount)?;
    Ok(())
}

// Get the bundled OCaml backend path
fn get_bundled_ocaml_backend() -> Result<PathBuf, String> {
    let current_exe =
        std::env::current_exe().map_err(|e| format!("Failed to get current executable: {}", e))?;

    let exe_dir = current_exe
        .parent()
        .ok_or("Failed to get executable directory")?;

    // Try different possible locations
    let possible_paths = [
        // Development mode (from project root/src-tauri)
        exe_dir.join("../ocaml-backend"),
        exe_dir.join("../../ocaml-backend"),
        // Production mode (bundled)
        exe_dir.join("ocaml-backend"),
        // macOS app bundle - the actual path based on bundle structure
        exe_dir.join("../Resources/_up_/ocaml-backend"),
        // Alternative macOS app bundle paths
        exe_dir.join("../Resources/ocaml-backend"),
        // Linux/Windows production paths
        exe_dir.join("../ocaml-backend"),
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

// Setup OCaml environment - ensure shared database access
fn setup_ocaml_environment() -> Result<PathBuf, String> {
    let ocaml_backend = get_bundled_ocaml_backend()?;
    let shared_db_path = get_database_path()?;
    let ocaml_db_path = ocaml_backend.join("invoices.db");
    
    // Always ensure OCaml backend uses the same database as Rust
    // Create a symlink if possible, otherwise copy
    if ocaml_db_path.exists() {
        fs::remove_file(&ocaml_db_path)
            .map_err(|e| format!("Failed to remove old OCaml database: {}", e))?;
    }
    
    // Try to create a symlink first (more efficient), fallback to copy
    match std::os::unix::fs::symlink(&shared_db_path, &ocaml_db_path) {
        Ok(_) => {},
        Err(_) => {
            // Symlink failed, copy the database instead
            if shared_db_path.exists() {
                fs::copy(&shared_db_path, &ocaml_db_path)
                    .map_err(|e| format!("Failed to copy database for OCaml backend: {}", e))?;
            } else {
                // Create empty database file if shared database doesn't exist yet
                fs::File::create(&ocaml_db_path)
                    .map_err(|e| format!("Failed to create OCaml database: {}", e))?;
            }
        }
    }

    Ok(ocaml_backend)
}

// Sync database from OCaml backend to main app database (no longer needed with shared DB)
fn sync_ocaml_database(_ocaml_backend: &Path) -> Result<(), String> {
    // No sync needed since both use the same database file
    Ok(())
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

    // Find the compiled OCaml binary
    let binary_path = ocaml_backend.join("_build/default/src/main.exe");
    
    // Check if the binary exists (should be bundled pre-compiled)
    if !binary_path.exists() {
        // Fallback: try to build if in development mode
        if cfg!(debug_assertions) {
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
        } else {
            return Err("OCaml binary not found in bundle. The application may not be properly built.".to_string());
        }
    }

    // Run the invoice generation using the compiled binary directly
    let mut cmd = Command::new(&binary_path);
    cmd.current_dir(&ocaml_backend);

    if dry_run {
        cmd.arg("-dry");
    }

    let output = cmd
        .output()
        .map_err(|e| format!("Failed to execute invoice generation: {}", e))?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();

        // Copy generated PDFs to user output directory
        let copied_files = copy_generated_pdfs(&ocaml_backend)?;

        // In production, sync the database after invoice generation
        if !cfg!(debug_assertions) {
            sync_ocaml_database(&ocaml_backend)?;
        }

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

#[tauri::command]
fn reset_database() -> Result<(), String> {
    let db_path = get_database_path()?;
    
    // Remove existing database file if it exists
    if db_path.exists() {
        fs::remove_file(&db_path)
            .map_err(|e| format!("Failed to remove database file: {}", e))?;
    }
    
    // Create new database with fresh schema and example data
    let conn = connect_database()?;
    init_database(&conn)?;
    
    // Also reset settings to defaults
    let settings_path = get_settings_path()?;
    if settings_path.exists() {
        fs::remove_file(&settings_path)
            .map_err(|e| format!("Failed to remove settings file: {}", e))?;
    }
    
    // Create fresh default settings
    let _ = get_app_settings()?;
    
    Ok(())
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
            save_app_settings,
            get_config_setting,
            set_config_setting,
            is_first_run,
            reset_database
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
