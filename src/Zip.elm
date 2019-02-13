module Zip exposing (AFile, zip)
import Bytes exposing (Bytes)
import Bytes.Encode as Encode exposing (Encoder, encode, string)


type alias AFile = { filename : String, content : String }


-- This is basically a zip encoder, should be split to it's own module
-- only implements no compression no encryption, minimum to get something
zip : List AFile -> Bytes
zip files =
  files |> zipEncoder |> encode

-- Per ZIP File Format Specification.TXT version 6.3.2 September 28, 2007
-- Using jxxcarlson/elm-tar/2.2.2/src/Tar.elm as reference for elm / Bytes.Encoder usage
zipEncoder : List AFile -> Encoder
zipEncoder files =
  let
      files_encoders = List.map zipFileEncoder files
      archive_decryption_header = string "todo"
      archive_extra_data_record = string "todo"
      central_directory = string "todo"
      zip64_end_of_central_directory_record = string "todo"
      zip64_end_of_central_directory_locator = string "todo"
      end_of_central_directory_record = string "todo"

      endheaders = [
        archive_decryption_header,
        archive_extra_data_record,
        central_directory,
        zip64_end_of_central_directory_record,
        zip64_end_of_central_directory_locator,
        end_of_central_directory_record]
  in
      Encode.sequence (files_encoders ++ endheaders)


zipFileEncoder afile =
  let
    local_file_header = zipLocalFileHeaderEncoder afile
    file_data = string "todo"
    data_descriptor = string "todo"
  in
    Encode.sequence [local_file_header, file_data, data_descriptor]


zipLocalFileHeaderEncoder afile =
  let
    local_file_header_signature = Encode.unsignedInt32 Bytes.LE 0x04034b50
    version_needed_to_extract = string "todo"
    general_purpose_bit_flag = string "todo"
    compression_method = string "todo"
    last_mod_file_time = string "todo"
    last_mod_file_date = string "todo"
    crc_32 = string "todo"
    compressed_size = string "todo"
    uncompressed_size = string "todo"
    file_name_length = string "todo"
    file_name = string "todo"
    extra_field = string "todo"
  in
  Encode.sequence [
      local_file_header_signature,
      version_needed_to_extract,
      general_purpose_bit_flag,
      compression_method,
      last_mod_file_time,
      last_mod_file_date,
      crc_32,
      compressed_size,
      uncompressed_size,
      file_name_length,
      file_name,
      extra_field
    ]


