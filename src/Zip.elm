module Zip exposing (AFile, zip)
import Bytes exposing (Bytes, Endianness(..))
import Bytes.Encode as Encode exposing (Encoder, encode, string)
import Bytes.Decode as Decode exposing (Decoder, loop, Step(..))
import CRC32 exposing (calcCrc32, CRC32)


{-
 Limitations of this zip implementation:

 - compress only
 - store only, i.e. 1:1 compression ratio
 - only decompresses with unzip
  - off by 4 header size error
 - no time stamps
 - no attributes
 - not tested with subdirectories (maybe will fail due to lack of attributes)
-}


type alias AFile = { filename : String, content : Bytes }

type alias AFileZipData = { filename : String, content : Bytes, length : Int, crc32 : Int }


-- This is basically a zip encoder, should be split to it's own module
-- only implements no compression no encryption, minimum to get something
zip : CRC32 -> List AFile -> Bytes
zip crcobj files =
  files |> zipEncoder crcobj |> encode


type alias ZipData =
  { filename: String, content: List Int, crc32 : Int, n : Int, header_and_content_width: Int, relative_offset_of_local_header: Int }



listStep : Decoder a -> (Int, List a) -> Decoder (Step (Int, List a) (List a))
listStep decoder (n, xs) =
  if n <= 0 then
    Decode.succeed (Done (List.reverse xs))
  else
    Decode.map (\x -> Loop (n - 1, x :: xs)) decoder


bytesToUint8 bytes =
  let
    decoder = loop ((Bytes.width bytes), []) (listStep Decode.unsignedInt8)
  in
    Decode.decode decoder bytes |> Maybe.withDefault []


computeZipData : CRC32 -> Int -> AFile -> ZipData
computeZipData crcobj offset afile =
  let
    content = afile.content |> bytesToUint8
    n = List.length content
  in
    {
      filename = afile.filename,
      content = content,
      crc32 = content |> calcCrc32 crcobj,
      n = n,
      header_and_content_width = (zipLocalFileHeaderSize afile.filename) + n,
      relative_offset_of_local_header = offset
    }


g_version_made_by = u16 10 -- 1.0, MSDOS
g_version_needed_to_extract = u16 10 -- 1.0


zipCentralDirectoryFileHeaderSize filename =
  (2 * 6 + 4 * 3 + 2 * 5 + 4 + 4 + 4 + (Encode.getStringWidth filename))

zipCentralDirectoryFileHeader data =
  let
    version_made_by = g_version_made_by
    version_needed_to_extract = g_version_needed_to_extract
    general_purpose_bit_flag = z16 -- TODO
    compression_method = z16 -- store, i.e. uncompressed
    last_mod_file_time = z16 -- TODO 2 second units
    last_mod_file_date = z16 -- TODO
    crc_32 = u32 data.crc32
    compressed_size = u32 <| data.n
    uncompressed_size = compressed_size
    file_name_length = u16 <| Encode.getStringWidth data.filename
    extra_field_length = z16
    file_comment_length = z16
    disk_number_start = z16 -- TODO
    internal_file_attributes = z16 -- TODO
    external_file_attributes = z32 -- TODO
    relative_offset_of_local_header = u32 data.relative_offset_of_local_header
    file_name = string data.filename
    extra_field = string ""
    file_comment = string ""
  in
    Encode.sequence [
        u32 0x02014b50, -- central file header signature
        version_made_by,
        version_needed_to_extract,
        general_purpose_bit_flag,
        compression_method,
        last_mod_file_time,
        last_mod_file_date,
        crc_32,
        compressed_size,
        uncompressed_size,
        file_name_length,
        extra_field_length,
        file_comment_length,
        disk_number_start,
        internal_file_attributes,
        external_file_attributes,
        relative_offset_of_local_header,
        file_name,
        extra_field,
        file_comment
      ]


zipCentralDirectory files_data =
  let
    headers = List.map zipCentralDirectoryFileHeader files_data
    digital_signature =
      Encode.sequence [
        u32 0x05054b50,
        z16, -- size_of_data TODO wrong
        string ""
      ]
    zip64_end_of_central_directory_record = string ""
    zip64_end_of_central_directory_locator = string ""
    end_of_central_directory_record = zipEndCentralDirectory files_data
  in
    Encode.sequence (headers ++ -- [digital_signature])
      [
        zip64_end_of_central_directory_record,
        zip64_end_of_central_directory_locator,
        end_of_central_directory_record
      ]
      )


listSum l =
  List.foldr (\s a -> s + a) 0 l


zipCentralDirectorySize files_data =
  let
      headers_size = files_data |> List.map .filename |> List.map zipCentralDirectoryFileHeaderSize |> listSum
  in
    headers_size -- + zipEndCentralDirectorySize


zipEndCentralDirectorySize =
  (4 + 2 + 2 + 2 + 2 + 4 + 4 + 2)


zipEndCentralDirectory files_data =
  let
    number_of_files_u16 = u16 <| (List.length files_data)
    end_of_central_dir_signature = u32 0x06054b50
    number_of_this_disk = z16
    number_of_the_disk_with_the_start_of_the_central_directory = z16
    central_directory_on_this_disk = number_of_files_u16
    total_number_of_entries_in_the_central_directory = number_of_files_u16
    size_of_the_central_directory = u32 (zipCentralDirectorySize files_data)
    -- todo: cache this, computed twice
    start_offset = files_data |> List.map .header_and_content_width |> listSum
    offset_of_start_of_central_directory_with_respect_to_the_starting_disk_number = u32 start_offset
    dotzip_file_comment_length = z16
    dotzip_file_comment = string ""
  in
    Encode.sequence [
        end_of_central_dir_signature,
        number_of_this_disk,
        number_of_the_disk_with_the_start_of_the_central_directory,
        central_directory_on_this_disk,
        total_number_of_entries_in_the_central_directory,
        size_of_the_central_directory,
        offset_of_start_of_central_directory_with_respect_to_the_starting_disk_number,
        dotzip_file_comment_length,
        dotzip_file_comment
      ]

-- Per ZIP File Format Specification.TXT version 6.3.2 September 28, 2007
-- Using jxxcarlson/elm-tar/2.2.2/src/Tar.elm as reference for elm / Bytes.Encoder usage
zipEncoder : CRC32 -> List AFile -> Encoder
zipEncoder crcobj files =
  let
      helper file (offset, retl) =
        let
            augfile = computeZipData crcobj offset file
        in
            (offset + augfile.header_and_content_width, List.append retl [augfile])
      (last_offset, files_data) = List.foldl helper (0, []) files
      files_encoders = List.map zipFileEncoder files_data
      central_directory = zipCentralDirectory files_data

      endheaders = [
        central_directory
        ]
  in
      Encode.sequence (files_encoders ++ endheaders)


zipFileEncoder : ZipData -> Encoder
zipFileEncoder zip_data =
  let
    local_file_header = zipLocalFileHeaderEncoder zip_data
    file_data = zip_data.content |> List.map Encode.unsignedInt8 |> Encode.sequence
    -- This descriptor only appears if bit 3 of the general purpose bit flag is set (6.3.2 V.C)
    -- data_descriptor = string "todo"
  in
    Encode.sequence [local_file_header, file_data]


u32 = Encode.unsignedInt32 LE
u16 = Encode.unsignedInt16 LE
z32 = u32 0
z16 = u16 0


zipLocalFileHeaderSize filename =
  4 + 2 + 2 + 2 + 2 + 2 + 4 + 4 + 4 + 2 + 2 + (Encode.getStringWidth filename)

zipLocalFileHeaderEncoder afile =
  let
    local_file_header_signature = u32 0x04034b50
    version_needed_to_extract = g_version_needed_to_extract
    general_purpose_bit_flag = z16 -- TODO
    compression_method = z16 -- TODO
    last_mod_file_time = z16 -- TODO should be either now or from file name or get from headers?
    last_mod_file_date = z16 -- TODO -"-
    crc_32 = u32 <| afile.crc32
    compressed_size = u32 <| afile.n
    uncompressed_size = compressed_size
    file_name_length = u16 <| Encode.getStringWidth afile.filename
    extra_field_length = z16
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
      extra_field_length,
      file_name,
      extra_field
    ]


