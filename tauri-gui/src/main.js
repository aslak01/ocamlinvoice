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
  } else if (tabName === 'history') {
    // Load invoice history
    loadInvoiceHistory();
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

// Invoice History Functions
async function loadInvoiceHistory() {
  try {
    showHistoryLoading(true);
    const invoices = await invoke('get_all_invoices');
    displayInvoices(invoices);
  } catch (error) {
    showHistoryError(`Error loading invoices: ${error}`);
  }
}

function showHistoryLoading(show) {
  document.getElementById('invoices-loading').classList.toggle('hidden', !show);
  document.getElementById('invoices-table').classList.toggle('hidden', show);
  document.getElementById('invoices-empty').classList.add('hidden');
  document.getElementById('invoices-error').classList.add('hidden');
}

function showHistoryError(message) {
  document.getElementById('invoices-loading').classList.add('hidden');
  document.getElementById('invoices-table').classList.add('hidden');
  document.getElementById('invoices-empty').classList.add('hidden');
  document.getElementById('invoices-error').classList.remove('hidden');
  document.getElementById('invoices-error').textContent = message;
}

function displayInvoices(invoices) {
  showHistoryLoading(false);
  
  if (invoices.length === 0) {
    document.getElementById('invoices-table').classList.add('hidden');
    document.getElementById('invoices-empty').classList.remove('hidden');
    return;
  }
  
  const tbody = document.getElementById('invoices-tbody');
  tbody.innerHTML = '';
  
  invoices.forEach(invoice => {
    const row = document.createElement('tr');
    row.dataset.invoiceId = invoice.id;
    
    row.innerHTML = `
      <td><span class="invoice-number">${invoice.invoice_number}</span></td>
      <td>${invoice.service}</td>
      <td>${formatDate(invoice.invoice_date)}</td>
      <td>${formatDate(invoice.due_date)}</td>
      <td>${formatDate(invoice.created_at)}</td>
      <td>
        <button class="action-btn" onclick="previewInvoice(${invoice.id})">Preview</button>
        <button class="action-btn" onclick="downloadInvoice(${invoice.id}, '${invoice.invoice_number}')">Download</button>
      </td>
    `;
    
    row.addEventListener('click', () => previewInvoice(invoice.id));
    tbody.appendChild(row);
  });
  
  document.getElementById('invoices-table').classList.remove('hidden');
}

async function previewInvoice(invoiceId) {
  try {
    // Remove previous selection
    document.querySelectorAll('#invoices-tbody tr').forEach(tr => {
      tr.classList.remove('selected');
    });
    
    // Add selection to clicked row
    const row = document.querySelector(`tr[data-invoice-id="${invoiceId}"]`);
    if (row) {
      row.classList.add('selected');
    }
    
    const invoice = await invoke('get_invoice_by_id', { id: invoiceId });
    
    // Show PDF in iframe
    const pdfFrame = document.getElementById('pdf-frame');
    const pdfViewer = document.getElementById('pdf-viewer');
    const pdfPlaceholder = document.getElementById('pdf-placeholder');
    
    // Convert base64 to blob URL
    const pdfBlob = base64ToBlob(invoice.pdf_base64, 'application/pdf');
    const pdfUrl = URL.createObjectURL(pdfBlob);
    
    pdfFrame.src = pdfUrl;
    pdfViewer.classList.remove('hidden');
    pdfPlaceholder.classList.add('hidden');
    
  } catch (error) {
    showStatus(`Error loading invoice: ${error}`, 'error');
  }
}

async function downloadInvoice(invoiceId, invoiceNumber) {
  try {
    const invoice = await invoke('get_invoice_by_id', { id: invoiceId });
    
    // Convert base64 to blob and download
    const pdfBlob = base64ToBlob(invoice.pdf_base64, 'application/pdf');
    const url = URL.createObjectURL(pdfBlob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `invoice-${invoiceNumber}.pdf`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showStatus(`Invoice ${invoiceNumber} downloaded successfully!`, 'success');
  } catch (error) {
    showStatus(`Error downloading invoice: ${error}`, 'error');
  }
}

// Helper functions
function formatDate(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
}

function base64ToBlob(base64, mimeType) {
  const byteCharacters = atob(base64);
  const byteNumbers = new Array(byteCharacters.length);
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  const byteArray = new Uint8Array(byteNumbers);
  return new Blob([byteArray], { type: mimeType });
}
