(* PDF document structure generation *)

(* PDF document template *)
let generate_pdf_structure content_string =
  let content_length = String.length content_string in
  Printf.sprintf 
{|%%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Resources 4 0 R
/Contents 5 0 R
>>
endobj

4 0 obj
<<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
/Encoding /WinAnsiEncoding
>>
>>
>>
endobj

5 0 obj
<<
/Length %d
>>
stream
%s
endstream
endobj

xref
0 6
0000000000 65535 f 
0000000010 00000 n 
0000000053 00000 n 
0000000125 00000 n 
0000000221 00000 n 
0000000329 00000 n 
trailer
<<
/Size 6
/Root 1 0 R
>>
startxref
%d
%%%%EOF|}
    content_length
    content_string
    (629 + content_length)

(* Write PDF to file *)
let write_pdf_to_file content filename =
  let pdf_content = generate_pdf_structure content in
  let oc = open_out filename in
  output_string oc pdf_content;
  close_out oc

(* Generate PDF from content operations *)
let create_pdf_from_content content_ops filename =
  let content_string = String.concat "\n" content_ops in
  write_pdf_to_file content_string filename