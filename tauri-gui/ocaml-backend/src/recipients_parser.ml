open Types

let parse_recipient_block lines =
  match lines with
  | [] -> None
  | name :: rest ->
    let (email_line, address_lines) = 
      match rest with
      | [] -> ("", [])
      | first :: remaining ->
        if String.contains first '@' then
          (first, remaining)
        else
          ("", first :: remaining)
    in
    let orgno = "" in (* Default empty orgno for recipients *)
    Some {
      name = String.trim name;
      orgno = orgno;
      adr = List.map String.trim (email_line :: address_lines) |> List.filter (fun s -> s <> "")
    }

let parse_recipients_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    
    let lines = String.split_on_char '\n' content 
                |> List.map String.trim in
    
    let rec group_recipients acc current_group = function
      | [] -> 
        if current_group = [] then List.rev acc
        else List.rev (List.rev current_group :: acc)
      | line :: rest ->
        if line = "" then
          if current_group = [] then
            group_recipients acc [] rest
          else
            group_recipients (List.rev current_group :: acc) [] rest
        else
          group_recipients acc (line :: current_group) rest
    in
    
    let groups = group_recipients [] [] lines in
    List.filter_map parse_recipient_block groups
  with
  | Sys_error _ -> []
  | exn -> 
    Printf.eprintf "Error parsing recipients file: %s\n" (Printexc.to_string exn);
    []

let recipients_file_exists filename =
  try
    let _ = Unix.stat filename in
    true
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> false
  | _ -> false