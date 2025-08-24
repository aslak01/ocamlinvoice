type invoice_record = {
  id: int;
  invoice_number: string;
  pdf_content: string;
  created_at: string;
}

val get_or_create_connection : unit -> (Sqlite3.db, string) result

val generate_invoice_number : Sqlite3.db -> (string, string) result

val store_invoice : Sqlite3.db -> string -> Types.invoice_data -> string -> (unit, string) result

val close_connection : Sqlite3.db -> (unit, string) result