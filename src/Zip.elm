module Zip exposing (AFile, zip)
import Bytes exposing (Bytes, Endianness(..))
import Bytes.Encode as Encode exposing (Encoder, encode, string)
import CRC32 exposing (calcCrc32, CRC32)


type alias AFile = { filename : String, content : String }

type alias AFileZipData = { filename : String, content : String, crc32 : Int }


-- This is basically a zip encoder, should be split to it's own module
-- only implements no compression no encryption, minimum to get something
zip : CRC32 -> List AFile -> Bytes
zip crcobj files =
  files |> zipEncoder crcobj |> encode


computeZipData crcobj offset afile =
  {
    filename = afile.filename,
    content = afile.content,
    crc32 = afile.content |> String.toList |> List.map Char.toCode |> calcCrc32 crcobj,
    header_and_content_width = (zipLocalFileHeaderSize afile.filename) + (Encode.getStringWidth afile.content),
    relative_offset_of_local_header = offset
  }


g_version_made_by = u16 10 -- 1.0, MSDOS
g_version_needed_to_extract = u16 10 -- 1.0


zipCentralDirectoryFileHeaderSize filename =
  (2 * 6 + 4 * 3 + 2 * 5 + 4 + 4 + (Encode.getStringWidth filename))

zipCentralDirectoryFileHeader data =
  let
    version_made_by = g_version_made_by
    version_needed_to_extract = g_version_needed_to_extract
    general_purpose_bit_flag = z16 -- TODO
    compression_method = z16 -- store, i.e. uncompressed
    last_mod_file_time = z16 -- TODO 2 second units
    last_mod_file_date = z16 -- TODO
    crc_32 = u32 data.crc32
    compressed_size = u32 <| String.length data.content -- TODO: wrong if this is utf-8? should switch to AFile.content : Bytes
    uncompressed_size = compressed_size
    file_name_length = u16 <| String.length data.filename
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
    end_of_central_dir_signature = u32 0x06054b50
    number_of_this_disk = z16
    number_of_the_disk_with_the_start_of_the_central_directory = z16
    central_directory_on_this_disk = u16 2 -- TODO copied from output of zip
    total_number_of_entries_in_the_central_directory = u16 <| (List.length files_data) -- +1 ?
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
    compressed_size = u32 <| String.length afile.content
    uncompressed_size = compressed_size
    file_name_length = u16 <| String.length afile.filename
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


