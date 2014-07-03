(*
 * Copyright (c) 2013 Jeremy Yallop.
 *
 * This file is distributed under the terms of the MIT License.
 * See the file LICENSE for details.
 *)

open Static
open Memory

let rec format : type a. a typ -> Format.formatter -> a -> unit
  = fun typ fmt v -> match typ with
    Void -> Format.pp_print_string fmt ""
  | Primitive p ->
    Format.pp_print_string fmt (Value_printing_stubs.string_of_prim p v)
  | Pointer _ -> format_ptr fmt v
  | Struct _ -> format_structured fmt v
  | Union _ -> format_structured fmt v
  | Array (a, n) -> format_array fmt v
  | Bigarray ba -> Format.fprintf fmt "<bigarray %a>"
    (fun fmt -> Type_printing.format_typ fmt) typ
  | Abstract _ -> format_structured fmt v
  | OCaml _ -> format_ocaml fmt v
    (* For now, just print the underlying value in a view *)
  | View {write; ty} -> format ty fmt (write v)
and format_structured : type a b. Format.formatter -> (a, b) structured -> unit
  = fun fmt ({structured = CPointer {reftype}} as s) ->
    let open Format in
    match reftype with
    | Struct {fields} ->
      fprintf fmt "{@;<1 2>@[";
      format_fields "," fields fmt s;
      fprintf fmt "@]@;<1 0>}"
    | Union {ufields} ->
      fprintf fmt "{@;<1 2>@[";
      format_fields " |" ufields fmt s;
      fprintf fmt "@]@;<1 0>}"
    | Abstract abs ->
      pp_print_string fmt "<abstract>"
    | _ -> raise (Unsupported "unknown structured type")
and format_array : type a. Format.formatter -> a carray -> unit
  = fun fmt ({astart = CPointer {reftype}; alength} as arr) ->
    let open Format in
    fprintf fmt "{@;<1 2>@[";
    for i = 0 to alength - 1 do
      format reftype fmt (CArray.get arr i);
      if i <> alength - 1 then
        fprintf fmt ",@;"
    done;
    fprintf fmt "@]@;<1 0>}"
and format_ocaml : type a. Format.formatter -> a ocaml -> unit =
  let offset fmt = function
    | 0 -> ()
    | n -> Format.fprintf fmt "@ @[[offset:%d]@]" n
  and float_array fmt arr =
    Format.fprintf fmt "[|@;<1 2>@[";
    let len = Array.length arr in
    for i = 0 to len - 1 do
      Format.pp_print_float fmt arr.(i);
      if i <> len - 1 then
        Format.fprintf fmt ",@;"
    done;
    Format.fprintf fmt "@]@;<1 0>|]"
  in
  fun fmt (OCamlRef (off, obj, ty)) -> match ty with
  | String -> Format.fprintf fmt "%S%a" obj offset off
  | Bytes -> Format.fprintf fmt "%S%a" (Bytes.to_string obj) offset off
  | FloatArray -> Format.fprintf fmt "%a%a" float_array obj offset off
and format_fields : type a b. string -> (a, b) structured boxed_field list ->
                              Format.formatter -> (a, b) structured -> unit
  = fun sep fields fmt s ->
    let last_field = List.length fields - 1 in
    let open Format in
    List.iteri
      (fun i (BoxedField ({ftype; foffset; fname} as f)) ->
        fprintf fmt "@[%s@] = @[%a@]%s@;" fname (format ftype) (getf s f)
          (if i <> last_field then sep else ""))
      fields
and format_ptr : type a. Format.formatter -> a ptr -> unit
  = fun fmt (CPointer {raw_ptr; reftype; pbyte_offset}) ->
    Format.fprintf fmt "%s"
      (Value_printing_stubs.string_of_pointer
         (Raw.PtrType.(add raw_ptr (of_int pbyte_offset))))

let string_of typ v = Common.string_of (format typ) v
