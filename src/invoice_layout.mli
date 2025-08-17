(* Interface for invoice layout *)
open Types
open Pdf_text

(* Layout state management *)
type layout_state = {
  content : pdf_content;
  current_y : float;
  config : page_config;
}

val create_layout_state : page_config -> float -> layout_state

(* Main layout generation function *)
val generate_invoice_layout : page_config -> invoice_data -> layout_state