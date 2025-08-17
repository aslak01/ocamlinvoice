const { invoke } = window.__TAURI__.core;

// UI Elements
let currentTab = 'sender';
let fileData = {};

// Status management
function showStatus(message, type = 'info') {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = `status ${type}`;
  statusEl.classList.remove('hidden');
  
  if (type !== 'error') {
    setTimeout(() => {
      statusEl.classList.add('hidden');
    }, 3000);
  }
}

function showOutput(text) {
  const outputEl = document.getElementById('output');
  outputEl.textContent = text;
  outputEl.classList.remove('hidden');
}

// Tab management
function switchTab(tabName) {
  // Save current tab content before switching
  saveCurrentTabContent();
  
  // Update tab buttons
  document.querySelectorAll('.tab').forEach(tab => {
    tab.classList.remove('active');
  });
  document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
  
  // Update tab panels
  document.querySelectorAll('.tab-panel').forEach(panel => {
    panel.classList.remove('active');
  });
  document.getElementById(`${tabName}-tab`).classList.add('active');
  
  // Load content for new tab
  loadTabContent(tabName);
  currentTab = tabName;
}

function saveCurrentTabContent() {
  if (currentTab === 'invoice') {
    // Save both description and amount for invoice tab
    fileData.description = document.getElementById('description-editor').value;
    fileData.amount = document.getElementById('amount-editor').value;
  } else {
    // Save single content for other tabs
    const editorId = `${currentTab}-editor`;
    const editor = document.getElementById(editorId);
    if (editor) {
      fileData[currentTab] = editor.value;
    }
  }
}

function loadTabContent(tabName) {
  if (tabName === 'invoice') {
    // Load both description and amount for invoice tab
    document.getElementById('description-editor').value = fileData.description || '';
    document.getElementById('amount-editor').value = fileData.amount || '';
  } else {
    // Load single content for other tabs
    const editorId = `${tabName}-editor`;
    const editor = document.getElementById(editorId);
    if (editor) {
      editor.value = fileData[tabName] || '';
    }
  }
}

// File operations
async function loadAllFiles() {
  try {
    showStatus('Loading files...', 'info');
    const files = await invoke('read_all_files');
    
    fileData = {
      sender: files.sender,
      bankdetails: files.bankdetails,
      description: files.description,
      amount: files.amount,
      recipients: files.recipients
    };
    
    // Load current tab content
    loadTabContent(currentTab);
    showStatus('Files loaded successfully!', 'success');
  } catch (error) {
    showStatus(`Error loading files: ${error}`, 'error');
  }
}

async function saveAllFiles() {
  try {
    showStatus('Saving files...', 'info');
    
    // Save current tab content first
    saveCurrentTabContent();
    
    // Save all individual files
    await invoke('write_file', { filePath: 'sender.txt', content: fileData.sender || '' });
    await invoke('write_file', { filePath: 'bankdetails.txt', content: fileData.bankdetails || '' });
    await invoke('write_file', { filePath: 'recipients.txt', content: fileData.recipients || '' });
    
    // Save invoice details as separate files
    await invoke('save_invoice_details', { 
      description: fileData.description || '', 
      amount: fileData.amount || '' 
    });
    
    showStatus('All files saved successfully!', 'success');
  } catch (error) {
    showStatus(`Error saving files: ${error}`, 'error');
  }
}

async function generateInvoices(dryRun = false) {
  try {
    // Save files first
    await saveAllFiles();
    
    const mode = dryRun ? 'preview' : 'normal';
    showStatus(`Generating invoices in ${mode} mode...`, 'info');
    
    const output = await invoke('generate_invoices', { dryRun });
    showStatus(`Invoices generated successfully in ${mode} mode!`, 'success');
    showOutput(output);
  } catch (error) {
    showStatus(`Error generating invoices: ${error}`, 'error');
    showOutput(error);
  }
}

// Event listeners
window.addEventListener("DOMContentLoaded", async () => {
  // Tab switching
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', (e) => {
      const tabName = e.target.dataset.tab;
      switchTab(tabName);
    });
  });
  
  // Button events
  document.getElementById('save-btn').addEventListener('click', saveAllFiles);
  document.getElementById('generate-btn').addEventListener('click', () => generateInvoices(false));
  document.getElementById('preview-btn').addEventListener('click', () => generateInvoices(true));
  
  // Load initial data
  await loadAllFiles();
});
