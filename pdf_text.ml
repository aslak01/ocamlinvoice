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

let default_config = {
  width = 595.0;
  height = 842.0;
  margin = 50.0;
  font_size_title = 20.0;
  font_size_heading = 14.0;
  font_size_normal = 11.0;
  font_size_small = 9.0;
  line_height = 14.0;
}

let helvetica_font = Pdftext.Helvetica

let calculate_text_width text size =
  let width_in_millipoints = Pdfstandard14.textwidth false Pdftext.WinAnsiEncoding helvetica_font text in
  (float_of_int width_in_millipoints /. 1000.0) *. size

type pdf_content = string list

let empty_content = []

let add_to_content content new_ops = content @ new_ops

(* Text positioning operations *)
let text_at_position text x y size =
  let escaped_text = Formatting_utils.escape_pdf_string text in
  [
    "BT";
    Printf.sprintf "/F1 %.1f Tf" size;
    Printf.sprintf "%.1f %.1f %.1f %.1f %.1f %.1f Tm" 1.0 0.0 0.0 1.0 x y;
    Printf.sprintf "(%s) Tj" escaped_text;
    "ET";
  ]

let right_aligned_text text right_edge y size =
  let width = calculate_text_width text size in
  let x = right_edge -. width in
  text_at_position text x y size

(* Graphics operations *)
let horizontal_line x1 x2 y =
  [
    "q";
    "0.5 w";
    Printf.sprintf "%.1f %.1f m" x1 y;
    Printf.sprintf "%.1f %.1f l" x2 y;
    "S";
    "Q";
  ]

(* Higher-level text operations *)
type text_block = {
  content : pdf_content;
  height : float;
}

let create_text_block _config texts x y size =
  let y_ref = ref y in
  let content = List.fold_left (fun acc text ->
    let text_ops = text_at_position text x !y_ref size in
    y_ref := !y_ref -. (size +. 3.0);
    add_to_content acc text_ops
  ) empty_content texts in
  let total_height = y -. !y_ref in
  { content; height = total_height }

let create_address_block config company x y =
  let name_block = text_at_position company.Types.name x y config.font_size_heading in
  let org_line = text_at_position (Printf.sprintf "Org: %s" company.Types.orgno) x (y -. config.font_size_heading -. 3.0) config.font_size_small in
  let y_start = y -. config.font_size_heading -. config.font_size_small -. 6.0 in
  let addr_block = create_text_block config company.Types.adr x y_start config.font_size_normal in
  {
    content = add_to_content (add_to_content name_block org_line) addr_block.content;
    height = config.font_size_heading +. config.font_size_small +. addr_block.height +. 6.0;
  }

(* Table-like structure for line items *)
type column_config = {
  x : float;
  alignment : [`Left | `Right];
}

let create_table_header config headers columns y =
  let header_ops = List.map2 (fun header col_config ->
    match col_config.alignment with
    | `Left -> text_at_position header col_config.x y config.font_size_normal
    | `Right -> right_aligned_text header col_config.x y config.font_size_normal
  ) headers columns in
  List.flatten header_ops

let create_table_row config values columns y =
  let row_ops = List.map2 (fun value col_config ->
    let escaped_value = Formatting_utils.escape_pdf_string value in
    match col_config.alignment with
    | `Left -> text_at_position escaped_value col_config.x y config.font_size_normal
    | `Right -> right_aligned_text escaped_value col_config.x y config.font_size_normal
  ) values columns in
  List.flatten row_ops
