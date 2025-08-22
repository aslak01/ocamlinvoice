let parse_text_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    
    (* Split into lines and filter out empty lines at the end *)
    let lines = String.split_on_char '\n' content in
    let remove_trailing_empty_lines = function
      | [] -> []
      | lines ->
          let rev_lines = List.rev lines in
          let rec remove_empty = function
            | "" :: rest -> remove_empty rest
            | lines -> List.rev lines
          in
          remove_empty rev_lines
    in
    remove_trailing_empty_lines lines
  with
  | Sys_error _ -> []
  | exn -> 
    Printf.eprintf "Error parsing file %s: %s\n" filename (Printexc.to_string exn);
    []

let file_exists filename =
  try
    let _ = Unix.stat filename in
    true
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> false
  | _ -> false