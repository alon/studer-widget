module Zip exposing (AFile, zip)
import Bytes exposing (Bytes, Endianness(..))
import Bytes.Encode as Encode exposing (Encoder, encode, string)


type alias AFile = { filename : String, content : String }

type alias AFileZipData = { filename : String, content : String, crc32 : Int }


-- This is basically a zip encoder, should be split to it's own module
-- only implements no compression no encryption, minimum to get something
zip : List AFile -> Bytes
zip files =
  files |> zipEncoder |> encode


computeZipData afile =
  { filename = afile.filename, content = afile.content, crc32 = crc32 afile.content }


zipCentralDirectory files_data =
  string "todo"


-- Per ZIP File Format Specification.TXT version 6.3.2 September 28, 2007
-- Using jxxcarlson/elm-tar/2.2.2/src/Tar.elm as reference for elm / Bytes.Encoder usage
zipEncoder : List AFile -> Encoder
zipEncoder files =
  let
      files_data = List.map computeZipData files
      files_encoders = List.map zipFileEncoder files_data
      archive_decryption_header = string "todo"
      archive_extra_data_record = string "todo"
      central_directory = zipCentralDirectory files_data
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
    file_data = string afile.content
    -- This descriptor only appears if bit 3 of the general purpose bit flag is set (6.3.2 V.C)
    -- data_descriptor = string "todo"
  in
    Encode.sequence [local_file_header, file_data]


u32 = Encode.unsignedInt32 LE
u16 = Encode.unsignedInt16 LE
z32 = u32 0
z16 = u16 0


crc32 bytes =
  0 -- TODO


zipLocalFileHeaderEncoder afile =
  let
    local_file_header_signature = Encode.unsignedInt32 Bytes.LE 0x04034b50
    version_needed_to_extract = z16 -- TODO
    general_purpose_bit_flag = z16 -- TODO
    compression_method = z16 -- TODO
    last_mod_file_time = z16 -- TODO should be either now or from file name or get from headers?
    last_mod_file_date = z16 -- TODO -"-
    crc_32 = u32 <| afile.crc32
    compressed_size = u32 <| String.length afile.content
    uncompressed_size = compressed_size
    file_name_length = u16 <| String.length afile.filename
    extra_field_length = u16 0
    file_name = string afile.filename
    extra_field = string "" -- TODO - another way to encode zero bytes?
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


