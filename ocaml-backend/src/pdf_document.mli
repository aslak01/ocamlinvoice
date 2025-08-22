(* Interface for PDF document generation *)

(* Generate PDF document structure with content *)
val generate_pdf_structure : string -> string

(* Write PDF content to file *)
val write_pdf_to_file : string -> string -> unit

(* Create complete PDF from content operations *)
val create_pdf_from_content : string list -> string -> unit