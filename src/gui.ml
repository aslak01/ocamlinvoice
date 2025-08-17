let config_files = [
  ("sender.txt", "Sender Information");
  ("bankdetails.txt", "Bank Details");
  ("invoice_details", "Invoice Details");
  ("recipients.txt", "Recipients");
]

(* Special handling for invoice details which has two files *)
let is_invoice_details filename = filename = "invoice_details"

let get_invoice_files () =
  let description_file = "config/description.txt" in
  let amount_file = "config/amount.txt" in
  (description_file, amount_file)

let has_gui_available () = true

let read_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    content
  with
  | Sys_error _ -> ""

let write_file filename content =
  try
    let oc = open_out filename in
    output_string oc content;
    close_out oc;
    true
  with
  | Sys_error _ -> false

let escape_js_string s =
  (* Only escape what's necessary for JavaScript strings, preserve Unicode *)
  let s = Str.global_replace (Str.regexp "\\\\") "\\\\\\\\" s in
  let s = Str.global_replace (Str.regexp "'") "\\\\'" s in
  let s = Str.global_replace (Str.regexp "\"") "\\\\\"" s in
  let s = Str.global_replace (Str.regexp "\n") "\\\\n" s in
  let s = Str.global_replace (Str.regexp "\r") "\\\\r" s in
  let s = Str.global_replace (Str.regexp "\t") "\\\\t" s in
  s

let generate_html_gui () =
  let (description_file, amount_file) = get_invoice_files () in
  
  let file_contents = List.map (fun (filename, label) ->
    if is_invoice_details filename then
      (* Special handling for invoice details - load both files *)
      let description_content = read_file description_file in
      let amount_content = read_file amount_file in
      (filename, label, description_content, Some amount_content)
    else
      let content = read_file ("config/" ^ filename) in
      (filename, label, content, None)
  ) config_files in
  
  let tabs_html = String.concat "\n" (List.map (fun (filename, label, _, _) ->
    Printf.sprintf {|        <button class="tab" onclick="switchTab('%s', '%s')">%s</button>|} 
    filename label label
  ) file_contents) in
  
  let file_data_js = String.concat ",\n" (List.map (fun (filename, label, content, amount_content) ->
    match amount_content with
    | Some amount ->
        Printf.sprintf {|    '%s': { label: '%s', content: '%s', amount: '%s' }|}
        filename label (escape_js_string content) (escape_js_string amount)
    | None ->
        Printf.sprintf {|    '%s': { label: '%s', content: '%s' }|}
        filename label (escape_js_string content)
  ) file_contents) in
  
  let css_part = {|<!DOCTYPE html>
<html>
<head>
    <title>Invoice Generator Configuration</title>
    <meta charset="UTF-8">
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
            margin: 0;
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 40px; 
            border-radius: 12px; 
            box-shadow: 0 8px 32px rgba(0,0,0,0.2); 
        }
        h1 { 
            color: #2c3e50; 
            text-align: center;
            margin-bottom: 30px;
            font-weight: 300;
            font-size: 2.5em;
            border-bottom: 3px solid #3498db; 
            padding-bottom: 15px; 
        }
        .tabs { 
            display: flex; 
            gap: 5px; 
            margin-bottom: 20px; 
            border-bottom: 2px solid #ecf0f1; 
            padding-bottom: 0;
        }
        .tab { 
            padding: 12px 24px; 
            background: #ecf0f1; 
            border: none; 
            cursor: pointer; 
            border-radius: 8px 8px 0 0; 
            transition: all 0.3s ease; 
            font-weight: 500;
            font-size: 14px;
        }
        .tab:hover { 
            background: #d5dbdb; 
            transform: translateY(-2px);
        }
        .tab.active { 
            background: #3498db; 
            color: white; 
            box-shadow: 0 4px 8px rgba(52,152,219,0.3);
        }
        .editor-section {
            margin-bottom: 20px;
        }
        #file-label {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 1.2em;
            font-weight: 500;
        }
        textarea { 
            width: 100%; 
            height: 450px; 
            font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Fira Code', 'Consolas', monospace; 
            font-size: 14px; 
            border: 2px solid #bdc3c7; 
            border-radius: 8px; 
            padding: 20px; 
            resize: vertical; 
            box-sizing: border-box;
            transition: border-color 0.3s ease;
            line-height: 1.5;
        }
        textarea:focus {
            outline: none;
            border-color: #3498db;
            box-shadow: 0 0 0 3px rgba(52,152,219,0.1);
        }
        .dual-input {
            display: none;
        }
        .dual-input.active {
            display: block;
        }
        .dual-input textarea {
            height: 200px;
            margin-bottom: 15px;
        }
        .dual-input label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #2c3e50;
        }
        .single-input {
            display: block;
        }
        .single-input.hidden {
            display: none;
        }
        .controls { 
            margin-top: 30px; 
            display: flex; 
            gap: 15px; 
            align-items: center; 
            justify-content: center;
            flex-wrap: wrap;
        }
        button { 
            padding: 12px 24px; 
            border: none; 
            border-radius: 6px; 
            cursor: pointer; 
            font-size: 16px; 
            font-weight: 500;
            transition: all 0.3s ease; 
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        .save-btn { 
            background: #27ae60; 
            color: white; 
        }
        .save-btn:hover { 
            background: #229954; 
        }
        .generate-btn { 
            background: #3498db; 
            color: white; 
        }
        .generate-btn:hover { 
            background: #2980b9; 
        }
        .dry-run-btn { 
            background: #f39c12; 
            color: white; 
        }
        .dry-run-btn:hover { 
            background: #e67e22; 
        }
        .status { 
            padding: 15px; 
            margin-top: 20px; 
            border-radius: 6px; 
            text-align: center;
            font-weight: 500;
        }
        .success { 
            background: #d5f4e6; 
            border: 2px solid #27ae60; 
            color: #1e8449; 
        }
        .error { 
            background: #fadbd8; 
            border: 2px solid #e74c3c; 
            color: #c0392b; 
        }
        .info {
            background: #d6eaf8;
            border: 2px solid #3498db;
            color: #2874a6;
        }
        .warning {
            background: #fff3cd;
            border: 2px solid #f39c12;
            color: #b7700a;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Invoice Generator</h1>
        
        <div class="warning">
            <strong>Note:</strong> This is a local HTML file interface. Use the buttons below to interact with the files.
        </div>
        
        <div class="tabs">|} in
  
  let body_part = {|        </div>
        
        <div class="editor-section">
            <h3 id="file-label">Loading...</h3>
            
            <!-- Single file editor -->
            <div id="single-input" class="single-input">
                <textarea id="editor" placeholder="File content will appear here..."></textarea>
            </div>
            
            <!-- Dual file editor for invoice details -->
            <div id="dual-input" class="dual-input">
                <label for="description-editor">Description:</label>
                <textarea id="description-editor" placeholder="Enter invoice description here..."></textarea>
                
                <label for="amount-editor">Amount (NOK):</label>
                <textarea id="amount-editor" placeholder="Enter amount here (e.g., 3750.50)"></textarea>
            </div>
            
            <input type="hidden" id="current-file">
        </div>
        
        <div class="controls">
            <button class="save-btn" onclick="saveCurrentFile()">Save Current File</button>
            <button class="generate-btn" onclick="generateInvoices(false)">Generate Invoices</button>
            <button class="dry-run-btn" onclick="generateInvoices(true)">Preview Mode</button>
        </div>
        
        <div id="status"></div>
    </div>

    <script>
        // File data embedded from OCaml
        const fileData = {|} in

  let js_part = {|        };
        
        let currentFile = '';
        
        function switchTab(filename, label) {
            // Save current file before switching
            if (currentFile && currentFile !== filename) {
                saveCurrentFile();
            }
            
            // Update UI
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            event.target.classList.add('active');
            
            // Load file content
            const data = fileData[filename];
            if (data) {
                document.getElementById('file-label').textContent = data.label;
                document.getElementById('current-file').value = filename;
                currentFile = filename;
                
                // Check if this is the invoice details tab (has amount field)
                if (data.amount !== undefined) {
                    // Show dual input layout
                    document.getElementById('single-input').classList.add('hidden');
                    document.getElementById('dual-input').classList.add('active');
                    
                    document.getElementById('description-editor').value = data.content.replace(/\\\\n/g, '\n');
                    document.getElementById('amount-editor').value = data.amount.replace(/\\\\n/g, '\n');
                } else {
                    // Show single input layout
                    document.getElementById('dual-input').classList.remove('active');
                    document.getElementById('single-input').classList.remove('hidden');
                    
                    document.getElementById('editor').value = data.content.replace(/\\\\n/g, '\n');
                }
            }
        }
        
        function saveCurrentFile() {
            const filename = document.getElementById('current-file').value;
            
            if (!filename) return;
            
            // Update local data based on current layout
            if (fileData[filename]) {
                if (fileData[filename].amount !== undefined) {
                    // Dual input mode
                    const description = document.getElementById('description-editor').value;
                    const amount = document.getElementById('amount-editor').value;
                    fileData[filename].content = description.replace(/\n/g, '\\\\n');
                    fileData[filename].amount = amount.replace(/\n/g, '\\\\n');
                } else {
                    // Single input mode
                    const content = document.getElementById('editor').value;
                    fileData[filename].content = content.replace(/\n/g, '\\\\n');
                }
            }
            
            showStatus('File content updated locally. Use Generate buttons to save to disk.', 'info');
        }
        
        function generateInvoices(dryRun) {
            saveCurrentFile();
            const mode = dryRun ? 'preview' : 'normal';
            showStatus('Processing files and generating invoices in ' + mode + ' mode...', 'info');
            
            setTimeout(() => {
                showStatus(
                    'Files updated! Please run the command line tool to generate invoices:<br>' +
                    '• Normal mode: dune exec src/main.exe<br>' +
                    '• Preview mode: dune exec src/main.exe -- -dry',
                    'success'
                );
            }, 1000);
        }
        
        function showStatus(message, type) {
            const status = document.getElementById('status');
            status.innerHTML = '<div class="status ' + type + '">' + message + '</div>';
            setTimeout(() => {
                if (type !== 'success') status.innerHTML = '';
            }, type === 'info' ? 3000 : 8000);
        }
        
        // Initialize first tab
        window.onload = function() {
            const firstTab = document.querySelector('.tab');
            if (firstTab) {
                firstTab.click();
            }
        };
        
        // Auto-save on tab switch and before unload
        window.addEventListener('beforeunload', saveCurrentFile);
    </script>
</body>
</html>|} in
  
  css_part ^ tabs_html ^ body_part ^ file_data_js ^ js_part

let show_config_editor () =
  Printf.printf "Generating GUI interface...\n";
  
  (* Generate the HTML file *)
  let html_content = generate_html_gui () in
  let gui_file = "invoice-gui.html" in
  
  if write_file gui_file html_content then (
    Printf.printf "GUI generated: %s\n" gui_file;
    Printf.printf "Opening in your default browser...\n";
    
    (* Try to open in default browser *)
    let open_cmd = match Sys.os_type with
      | "Win32" -> "start"
      | "Cygwin" -> "cygstart" 
      | _ -> if Sys.command "which open > /dev/null 2>&1" = 0 then "open" else "xdg-open"
    in
    
    let full_path = Unix.getcwd () ^ "/" ^ gui_file in
    let _ = Sys.command (Printf.sprintf "%s \"file://%s\" > /dev/null 2>&1 &" open_cmd full_path) in
    
    Printf.printf "GUI opened at: file://%s\n" full_path;
    Printf.printf "You can also manually open this file in any web browser.\n";
    Printf.printf "After editing files in the GUI, use the command line to generate invoices:\n";
    Printf.printf "  • Normal mode: dune exec src/main.exe\n";
    Printf.printf "  • Preview mode: dune exec src/main.exe -- -dry\n";
  ) else (
    Printf.printf "Error: Could not create GUI file\n";
    exit 1
  )