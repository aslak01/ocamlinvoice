(* Interface for PDF text operations *)

(* Page configuration *)
type page_config = {
  width : float;
  height : float;
  margin : float;
  font_size_title : float;
  font_size_heading : float;
  font_size_normal : float;
  font_size_small : float;
  line_height : float;
}

val default_config : page_config

(* PDF content type *)
type pdf_content = string list

val empty_content : pdf_content
val add_to_content : pdf_content -> string list -> pdf_content

(* Text measurement *)
val calculate_text_width : string -> float -> float

(* Basic text operations *)
val text_at_position : string -> float -> float -> float -> string list
val right_aligned_text : string -> float -> float -> float -> string list

(* Graphics operations *)
val horizontal_line : float -> float -> float -> string list

(* Higher-level text blocks *)
type text_block = {
  content : pdf_content;
  height : float;
}

val create_text_block : page_config -> string list -> float -> float -> float -> text_block
val create_address_block : page_config -> Types.company -> float -> float -> text_block

(* Table operations *)
type column_config = {
  x : float;
  alignment : [`Left | `Right];
}

val create_table_header : page_config -> string list -> column_config list -> float -> string list
val create_table_row : page_config -> string list -> column_config list -> float -> string list