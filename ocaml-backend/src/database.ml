open Sqlite3

type invoice_record = {
  id: int;
  invoice_number: string;
  invoice_data_json: string;
  pdf_content: string;
  created_at: string;
}

let database_file = "invoices.db"

let create_tables db =
  let tables = [
    ("invoice_counters", 
     "CREATE TABLE IF NOT EXISTS invoice_counters (
        year INTEGER PRIMARY KEY,
        counter INTEGER NOT NULL DEFAULT 0
      )");
    
    ("currencies",
     "CREATE TABLE IF NOT EXISTS currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        short TEXT NOT NULL,
        symbol TEXT
      )");
    
    ("companies",
     "CREATE TABLE IF NOT EXISTS companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        orgno TEXT NOT NULL,
        address TEXT NOT NULL
      )");
    
    ("banks",
     "CREATE TABLE IF NOT EXISTS banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accno TEXT NOT NULL,
        iban TEXT NOT NULL,
        bic TEXT NOT NULL,
        bank_name TEXT NOT NULL
      )");
    
    ("invoices",
     "CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        locale TEXT NOT NULL,
        currency_id INTEGER NOT NULL,
        your_company_id INTEGER NOT NULL,
        your_bank_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        author TEXT NOT NULL,
        service TEXT NOT NULL,
        pdf_title TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        vat_enabled BOOLEAN NOT NULL,
        vat_rate INTEGER NOT NULL,
        pdf_content BLOB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (currency_id) REFERENCES currencies(id),
        FOREIGN KEY (your_company_id) REFERENCES companies(id),
        FOREIGN KEY (your_bank_id) REFERENCES banks(id),
        FOREIGN KEY (customer_id) REFERENCES companies(id)
      )");
    
    ("line_items",
     "CREATE TABLE IF NOT EXISTS line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        price TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )");
    
    ("meta_strings",
     "CREATE TABLE IF NOT EXISTS meta_strings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )");
  ] in
  
  let rec create_all = function
    | [] -> Ok ()
    | (table_name, sql) :: rest ->
        match exec db sql with
        | Rc.OK -> create_all rest
        | rc -> Error ("Failed to create " ^ table_name ^ " table: " ^ (Rc.to_string rc))
  in
  create_all tables

let get_or_create_connection () =
  match db_open database_file with
  | db -> (
    match create_tables db with
    | Ok () -> Ok db
    | Error msg -> Error msg
  )
  | exception Sqlite3.Error msg -> Error ("Failed to open database: " ^ msg)

let generate_invoice_number db =
  let current_year = 
    let tm = Unix.localtime (Unix.time ()) in
    1900 + tm.tm_year in
  
  let get_counter_sql = "SELECT counter FROM invoice_counters WHERE year = ?" in
  let stmt = prepare db get_counter_sql in
  let _ = bind stmt 1 (Data.INT (Int64.of_int current_year)) in
  
  let counter = match step stmt with
    | Rc.ROW -> (
      match column stmt 0 with
      | Data.INT counter -> Int64.to_int counter
      | _ -> 0
    )
    | _ -> 0 in
  
  let _ = finalize stmt in
  
  let new_counter = counter + 1 in
  let invoice_number = Printf.sprintf "%d-%d" current_year new_counter in
  
  let upsert_sql = 
    "INSERT INTO invoice_counters (year, counter) VALUES (?, ?)
     ON CONFLICT(year) DO UPDATE SET counter = excluded.counter" in
  let stmt = prepare db upsert_sql in
  let _ = bind stmt 1 (Data.INT (Int64.of_int current_year)) in
  let _ = bind stmt 2 (Data.INT (Int64.of_int new_counter)) in
  
  match step stmt with
  | Rc.DONE -> 
    let _ = finalize stmt in
    Ok invoice_number
  | rc -> 
    let _ = finalize stmt in
    Error ("Failed to update counter: " ^ (Rc.to_string rc))

let store_invoice db invoice_number (invoice_data : Types.invoice_data) pdf_content =
  (* First store the invoice record itself with placeholder IDs *)
  let insert_invoice_sql = 
    "INSERT INTO invoices (invoice_number, locale, currency_id, your_company_id, your_bank_id, customer_id, 
     author, service, pdf_title, invoice_date, due_date, vat_enabled, vat_rate, pdf_content) 
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" in
  let stmt = prepare db insert_invoice_sql in
  let _ = bind stmt 1 (Data.TEXT invoice_number) in
  let _ = bind stmt 2 (Data.TEXT invoice_data.locale) in
  let _ = bind stmt 3 (Data.INT 1L) in (* placeholder currency_id *)
  let _ = bind stmt 4 (Data.INT 1L) in (* placeholder your_company_id *)
  let _ = bind stmt 5 (Data.INT 1L) in (* placeholder your_bank_id *)
  let _ = bind stmt 6 (Data.INT 1L) in (* placeholder customer_id *)
  let _ = bind stmt 7 (Data.TEXT invoice_data.author) in
  let _ = bind stmt 8 (Data.TEXT invoice_data.service) in
  let _ = bind stmt 9 (Data.TEXT invoice_data.pdf_title) in
  let _ = bind stmt 10 (Data.TEXT invoice_data.invoice_meta.invoice_date.value) in
  let _ = bind stmt 11 (Data.TEXT invoice_data.invoice_meta.due_date.value) in
  let _ = bind stmt 12 (Data.INT (if invoice_data.vat.enabled then 1L else 0L)) in
  let _ = bind stmt 13 (Data.INT (Int64.of_int invoice_data.vat.rate)) in
  let _ = bind stmt 14 (Data.BLOB pdf_content) in
  
  match step stmt with
  | Rc.DONE -> 
    let invoice_id = Int64.to_int (last_insert_rowid db) in
    let _ = finalize stmt in
    
    (* Store line items *)
    let rec store_line_items = function
      | [] -> Ok ()
      | item :: rest ->
        let line_sql = "INSERT INTO line_items (invoice_id, date, description, price) VALUES (?, ?, ?, ?)" in
        let stmt = prepare db line_sql in
        let _ = bind stmt 1 (Data.INT (Int64.of_int invoice_id)) in
        let _ = bind stmt 2 (Data.TEXT item.Types.date) in
        let _ = bind stmt 3 (Data.TEXT item.Types.description) in
        let _ = bind stmt 4 (Data.TEXT item.Types.price) in
        match step stmt with
        | Rc.DONE -> 
          let _ = finalize stmt in
          store_line_items rest
        | rc -> 
          let _ = finalize stmt in
          Error ("Failed to insert line item: " ^ (Rc.to_string rc))
    in
    
    store_line_items invoice_data.lines
      
  | rc -> 
    let _ = finalize stmt in
    Error ("Failed to store invoice: " ^ (Rc.to_string rc))

let close_connection db =
  match db_close db with
  | true -> Ok ()
  | false -> Error "Failed to close database connection"