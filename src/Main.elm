module Main exposing (main)
import Array exposing (..)
import Browser
import Html exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing (..)
import Http
import Regex exposing (..)
import File.Download as Download
import Tar exposing (..)
import Bytes exposing (Bytes)
import Bytes.Encode as Encode exposing (encode, string, Encoder)
import Bytes.Decode as Decode
import Zip exposing (AFile, zip)
import CRC32 exposing (crc32, CRC32)

-- My Main



type alias DateControlModel =
  -- todo: Maybe'fy
  { date: String }


type alias Model = {
    location: String,
    crc32: CRC32,
    m : ModelInner
  }


type CurrentDownload =
  NoCurrent
  | DownloadForSizeOnly String
  | DownloadAndDecode String Int


type ModelInner =
    Init
  | GettingServerFile {
      total: List String,
      next : List String,
      current : CurrentDownload,
      done : List AFile,
      first : DateControlModel,
      last : DateControlModel,
      size : Int
    }
  | Error String


defaultGettingServerFile = {
    total = [],
    current = NoCurrent,
    done = [],
    size = 0,
    first = defaultDateControlModel,
    last = defaultDateControlModel,
    next = []
  }


removePathTop path =
  let
    parts = String.split "/" path
    array = Array.fromList parts
    len = Array.length array
    remaining = Array.toList <| Array.slice 0 (len - 1) array
    ret = String.join "/" remaining
  in
    ret ++ "/"


init : String -> (Model, Cmd Msg)
init flags =
  let
    location = removePathTop flags
  in
    (
      {
        location = location,
        m = Init,
        crc32 = crc32
      },
      Http.get { url = location, expect = Http.expectString GotRoot }
    )


parse_hrefs : String -> List String
parse_hrefs s =
  List.map
    (Maybe.withDefault "")
    (flattenList
      (List.map .submatches (find hrefs_regex s)))


hrefs_regex =
  Maybe.withDefault Regex.never (Regex.fromString "href=\"([^\"]*)\"")


flattenList : List (List a) -> List a
flattenList l =
  case  l of
    [] -> []
    ((x :: z) :: y) -> x :: (flattenList (z :: y))
    [] :: y -> flattenList y


getFileAndDecode : String -> Int -> Cmd Msg
getFileAndDecode filename size =
  Http.request {
     method = "GET",
     url = filename ++ "#bla",
     headers = [],
     body = Http.emptyBody,
     tracker = Just "csv",
     timeout = Nothing,
     expect = Http.expectBytes GotFile (Decode.bytes size)
   }


getNextSize inner =
  case inner of
    GettingServerFile data ->
      case data.next of
        first :: rest ->
          (GettingServerFile { data | next = rest, current = DownloadForSizeOnly first },
           getFileAndDecode first 0,
           True)
        [] ->
          (inner, Cmd.none, False)
    _ -> (inner, Cmd.none, False)


getFullFile inner size =
  case inner of
    GettingServerFile data ->
      case data.current of
        DownloadForSizeOnly filename ->
          GettingServerFile { data | current = DownloadAndDecode filename size }
        _ ->
          inner
    _ -> inner



tar : List AFile -> Bytes
tar all_files =
  let
    files = List.filter (\f -> Bytes.width f.content /= 0) all_files
    transform = \f -> ({ defaultFileRecord | filename = f.filename }, BinaryData (.content f))
    data = List.map transform files
  in
    createArchive data



updateDateControl : DateControlMsg -> DateControlModel -> DateControlModel
updateDateControl msg model =
  case msg of
    UpdateDate date -> { model | date = date }


defaultDateControlModel =
  { date = "2019-01-01" }


currentToString current =
  case current of
    NoCurrent -> "NoCurrent"
    DownloadForSizeOnly s -> "DownloadForSizeOnly " ++ s
    DownloadAndDecode s i -> "DownloadAndDecode " ++ s ++ ", " ++ (String.fromInt i)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    DoNothing -> (model, Cmd.none)
    UpdateFirst submsg ->
      case model.m of
        GettingServerFile data ->
          ({ model | m = GettingServerFile { data | first = (updateDateControl submsg data.first ) }}, Cmd.none)
        _ ->
          (model, Cmd.none) -- and error??
    UpdateLast submsg ->
      case model.m of
        GettingServerFile data ->
          ({ model | m = GettingServerFile { data | last = (updateDateControl submsg data.last ) } }, Cmd.none)
        _ ->
          (model, Cmd.none) -- and error??
    RetrieveFilesToDownloadToUser ->
      case model.m of
        GettingServerFile data ->
          let
            next = modelSelectedDownloads model.m
            inner_start = GettingServerFile { data | next = next, done = [] } -- TODO: could avoid dropping all of done, only drop the ones we don't need now, i.e. not in next
            (new_inner, cmd, continue) = getNextSize inner_start
            new_model = { model | m = new_inner }
          in
            if continue then
              (new_model, cmd)
            else
              update DownloadToUser new_model
        _ ->
          (model, Cmd.none) -- and error? all of this needs to be moved into it's own model/update cycle
    DownloadToUser ->
      case model.m of
        GettingServerFile data ->
          let
            files = data.done
            empty = Encode.encode (Encode.string "")
            first_file = Maybe.withDefault (AFile "empty.set" empty) (List.head files)
            first = first_file.filename
            first_part = String.slice 2 ((String.length first) - 4) first
            filename_base = "studer_" ++ first_part ++ "_" ++ (String.fromInt (List.length files))
            use_tar = True -- TODO: pick this up from flags
            filename_ext = if use_tar then "tar" else "zip"
            filename = filename_base ++ "." ++ filename_ext
            cmd = if use_tar then
                Download.bytes filename "application/x-tar" (tar files)
              else
                Download.bytes filename "application/x-zip" (zip model.crc32 files)
            cmd_unused = Cmd.none
          in
            ( model, cmd )
        _ ->
          (model, Cmd.none) -- TODO - show an error to the user
    GotFile result ->
      case result of
        Ok content ->
          case model.m of
            GettingServerFile data ->
              case data.current of
                DownloadForSizeOnly filename ->
                  let
                    new_inner = getFullFile model.m data.size
                    cmd = getFileAndDecode filename data.size
                  in
                    ({ model | m = new_inner }, cmd)
                DownloadAndDecode filename size ->
                  let
                    new_inner = GettingServerFile { data | done = ({ filename = filename, content = content } :: data.done), current = NoCurrent }
                    (next_inner, cmd, continue) = getNextSize new_inner
                  in
                    if continue then
                      ({ model | m = next_inner}, cmd)
                    else
                      update DownloadToUser { model | m = new_inner }
                _ -> ({ model | m = Error "another unexpected case"}, Cmd.none)
            _ -> ({ model | m = Error "unexpected endcase, how do I prevent this at compile time?" }, Cmd.none)
        Err _ ->
          case model.m of
            GettingServerFile data ->
              ({ model | m = Error ("error downloading " ++ (currentToString data.current)) }, Cmd.none)
            _ ->
              ({ model | m = Error "error downloading and not in GettingServerFile, elm-help!" }, Cmd.none)
    GotRoot result ->
      case result of
        Ok result_body ->
          let
              parsed = parse_hrefs result_body
              csvs = List.sort <| List.filter (\s -> String.endsWith ".csv" (String.toLower s)) parsed
              parsedArray = Array.fromList csvs
              n = Array.length parsedArray
              lastIdx = n - 1
              firstItem = Array.get 0 parsedArray
              lastItem = Array.get lastIdx parsedArray
              firstDate = Maybe.map filenameToDate firstItem
              lastDate = Maybe.map filenameToDate lastItem
              first = Maybe.withDefault defaultDateControlModel lastDate
              last = Maybe.withDefault defaultDateControlModel lastDate
              inner_m = GettingServerFile {
                  defaultGettingServerFile |
                  total = csvs,
                  first = first,
                  last = last
                }
            in
              ({ model | m = inner_m }, Cmd.none)
        Err _ ->
          ({ model | m = Error "Get error" }, Cmd.none)
    Track progress ->
      case progress of
        Http.Receiving data ->
          case model.m of
            GettingServerFile gsf ->
              let
                new_m = GettingServerFile { gsf | size = Maybe.withDefault 0 data.size }
              in
                ({model | m = new_m}, Cmd.none)
            _ -> (model, Cmd.none)
        _ -> (model, Cmd.none)


type DateControlMsg =
  UpdateDate String


type Msg =
  DoNothing
  | GotRoot (Result Http.Error String)
  | GotFile (Result Http.Error Bytes)
  | RetrieveFilesToDownloadToUser
  | DownloadToUser
  | UpdateFirst DateControlMsg
  | UpdateLast DateControlMsg
  | Track Http.Progress


view : Model -> Html Msg
view model =
  case model.m of
    Init -> div [] [text "init"]
    Error s -> div [] [text s]
    GettingServerFile data ->
      let
          missing_count = String.fromInt <| List.length data.next
          downloaded_count = String.fromInt <| List.length data.done
          counts = [div [] [text ("missing " ++ missing_count ++ ", downloaded " ++ downloaded_count)]]
          current =
            case data.current of
              NoCurrent -> []
              DownloadForSizeOnly filename -> [div [] [text ("downloading " ++ filename ++ " for size")]]
              DownloadAndDecode filename size -> [div [] [text ("downloading " ++ filename ++ " of size " ++ (String.fromInt size))]]
          downloadDivs =
            case List.length data.total of
              0 -> []
              _ -> downloadDialog model.m
      in
        div [] (counts ++ current ++ downloadDivs)


dmyToCsvName d0 m0 y0 =
  let
    d = String.pad 2 '0' d0
    m = String.pad 2 '0' m0
    y = String.pad 2 '0' y0
  in
    "LG" ++ y ++ m ++ d ++ ".CSV"


filenameToDate filename =
  let
    y = String.slice 2 4 filename
    m = String.slice 4 6 filename
    d = String.slice 6 8 filename
    date = "20" ++ y ++ "-" ++ m ++ "-" ++ d
  in
    DateControlModel date


viewDateControl : DateControlModel -> List (Html DateControlMsg)
viewDateControl model =
  [ input [ type_ "date", value model.date, onInput UpdateDate ] [] ]
  {--
  [ input [ placeholder "day", value model.day, onInput UpdateDay ] [] ] ++
  [ input [ placeholder "month", value model.month, onInput UpdateMonth ] [] ] ++
  [ input [ placeholder "year", value model.year, onInput UpdateYear ] [] ]
  --}


dateToComponents date =
  (String.slice 2 4 date, String.slice 5 7 date, String.slice 8 10 date)




modelSelectedDownloads : ModelInner -> List String
modelSelectedDownloads model =
  case model of
    GettingServerFile data ->
      let
        first_date_or_nothing = data.first.date
        last_date_or_nothing = data.last.date
        first_date = if first_date_or_nothing == "" then last_date_or_nothing else first_date_or_nothing
        last_date = if last_date_or_nothing == "" then first_date_or_nothing else last_date_or_nothing
        in_range_h = \date -> ((date >= first_date) && (date <= last_date))
      in
        List.filter (\x -> (x |> filenameToDate |> .date |> in_range_h)) data.total
    _ ->
      []


humanReadableByteSize n =
  if n < 1024 then
    String.fromInt n
  else if n < (1024 * 1024) then
    String.fromInt (n // 1024) ++ " KiB"
  else if n < (1024 * 1024 * 1024) then
    String.fromInt (n // (1024 * 1024)) ++ " MiB"
  else
    String.fromInt (n // (1024 * 1024 * 1024)) ++ " GiB"


shortFileDescription : List String -> List (Html Msg)
shortFileDescription files =
  let
    n = List.length files
    estimatedSize = 200000 * n
    first = Maybe.withDefault "" <| List.head files
    last = Maybe.withDefault "" <| List.head (List.reverse files) -- # simpler way to get last? what code does this compile to - is the reverse actually done?
    files_text =
      if n >= 3 then
        [first, ".. " ++ (String.fromInt (n - 2)) ++ " more files ..", last]
      else
        files
    files_div = [div [] (List.map text files_text)]
    class_name = if estimatedSize > 1024 * 1024 * 10 then "large-size" else "small-size"
  in
    [span [class class_name] [text <| "Estimated size: " ++ (humanReadableByteSize estimatedSize)]] ++ files_div



downloadDialog model =
  case model of
    GettingServerFile data ->
      [ button [onClick RetrieveFilesToDownloadToUser] [(text "download")] ] ++
      [ text "first" ] ++
      List.map (Html.map UpdateFirst) (viewDateControl data.first) ++
      [ text "last" ] ++
      List.map (Html.map UpdateLast) (viewDateControl data.last) ++
        [div [id "files-to-download"]
          (shortFileDescription (modelSelectedDownloads model))
        ]
    _ -> []


subscriptions : Model -> Sub Msg
subscriptions model =
  Http.track "csv" Track


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

