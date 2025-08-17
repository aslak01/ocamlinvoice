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
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directory: {}", e))?;
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

fn get_project_root() -> Result<std::path::PathBuf, String> {
    let current_dir = std::env::current_dir()
        .map_err(|e| format!("Failed to get current directory: {}", e))?;
    
    // Check if we're in src-tauri subdirectory
    if current_dir.file_name() == Some("src-tauri".as_ref()) {
        // We're in src-tauri, go up two levels (src-tauri -> tauri-gui -> project root)
        let tauri_gui = current_dir.parent().unwrap();
        let project_root = tauri_gui.parent().unwrap().to_path_buf();
        Ok(project_root)
    } else if current_dir.file_name() == Some("tauri-gui".as_ref()) {
        // We're in tauri-gui, go to parent
        let parent = current_dir.parent().unwrap().to_path_buf();
        Ok(parent)
    } else {
        // Check if config directory exists in current directory
        let config_in_current = current_dir.join("config");
        if config_in_current.exists() {
            Ok(current_dir)
        } else {
            // Look for config directory in parent
            let parent = current_dir.parent().unwrap_or(&current_dir);
            let config_in_parent = parent.join("config");
            if config_in_parent.exists() {
                Ok(parent.to_path_buf())
            } else {
                Err("Could not find config directory".to_string())
            }
        }
    }
}

// Run invoice generation
#[tauri::command]
fn generate_invoices(dry_run: bool) -> Result<String, String> {
    let project_root = get_project_root()
        .map_err(|e| format!("Failed to find project root: {}", e))?;
    
    let mut cmd = Command::new("dune");
    cmd.current_dir(&project_root);
    cmd.arg("exec");
    cmd.arg("src/main.exe");
    
    if dry_run {
        cmd.arg("--");
        cmd.arg("-dry");
    }
    
    let output = cmd.output()
        .map_err(|e| format!("Failed to execute command: {}", e))?;
    
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

fn get_config_path(filename: &str) -> String {
    let project_root = get_project_root().unwrap_or_else(|_| std::env::current_dir().unwrap());
    
    project_root
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
            generate_invoices
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
