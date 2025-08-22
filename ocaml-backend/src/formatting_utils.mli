(* Interface for formatting utilities *)
open Types

(* Number and currency formatting *)
val format_number : float -> string
val format_currency : float -> currency -> string

(* Date formatting *)
val format_date : string -> string

(* Financial calculations *)
val calculate_vat : string -> int -> bool -> float * float * float

(* Localization *)
val lookup_simple_string : (string * string) list -> string -> string
val lookup_nested_string : (string * (string * string) list) list -> string -> string -> string

(* PDF text processing *)
val escape_pdf_string : string -> string