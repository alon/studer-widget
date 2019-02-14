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
import Zip exposing (AFile, zip)

-- My Main



type alias DateControlModel =
  -- todo: Maybe'fy
  { date: String }


type alias Model = {
    location: String,
    m : ModelInner
  }


type ModelInner =
    Init
  | GettingServerFile {
      next : (List String),
      current : Maybe String,
      done : (List AFile),
      first : DateControlModel,
      last : DateControlModel
    }
  | Error String


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
    location = Debug.log ("removePathTop" ++ flags) (removePathTop flags)
  in
    ({ location = location, m = Init }, Http.get { url = location, expect = Http.expectString GotRoot })


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


download : ModelInner -> (ModelInner, Cmd Msg)
download model =
  case model of
    GettingServerFile data ->
      case data.next of
        first :: rest ->
          (GettingServerFile { data | next = rest, current = Just first, done = data.done },
           Http.get {
               url = first ++ "#bla",
               expect = Http.expectString GotFile
             }
          )
        [] ->
          (model, Cmd.none)
    _ -> (model, Cmd.none)


tar : List AFile -> Bytes
tar all_files =
  let
    files = List.filter (\f -> String.length f.content /= 0) all_files
    bytes = \f -> (encode (string f.content))
    transform = \f -> ({ defaultFileRecord | filename = f.filename }, BinaryData (bytes f))
    data = List.map transform files
  in
    createArchive data



updateDateControl : DateControlMsg -> DateControlModel -> DateControlModel
updateDateControl msg model =
  case msg of
    UpdateDate date -> { model | date = date }


defaultDateControlModel =
  { date = "2019-01-01" }


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
    DownloadToUser ->
      case model.m of
        GettingServerFile data ->
          let
            filtered = modelSelectedDownloads model.m
            first_file = Maybe.withDefault (AFile "empty.set" "") (List.head filtered)
            first = first_file.filename 
            first_part = String.slice 2 ((String.length first) - 4) first
            filename = "studer_" ++ first_part ++ "_" ++ (Debug.toString (List.length filtered)) ++ ".tar"
          in
            ( model, (Download.bytes filename "application/x-tar" (tar filtered)))
        _ ->
          (model, Cmd.none) -- TODO - show an error to the user
    GotFile result ->
      case result of
        Ok content ->
          case model.m of
            GettingServerFile data ->
              case data.current of
                Just current ->
                  let
                    newmodel = GettingServerFile { data | done = ({ filename = current, content = content } :: data.done), current = Nothing }
                    (new_inner, cmd) = download newmodel
                  in
                    ({ model | m = new_inner }, cmd)
                _ -> ({ model | m = Error "another unexpected case"}, Cmd.none)
            _ -> ({ model | m = Error "unexpected endcase, how do I prevent this at compile time?" }, Cmd.none)
        Err _ ->
          case model.m of
            GettingServerFile data ->
              ({ model | m = Error ("error downloading " ++ (Debug.toString data.current)) }, Cmd.none)
            _ ->
              ({ model | m = Error "error downloading and not in GettingServerFile, elm-help!" }, Cmd.none)
    GotRoot result ->
      case result of
        Ok something ->
          let
              parsed = parse_hrefs something
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
              (inner_m, cmd) = download (GettingServerFile {
                  done = [],
                  next = csvs,
                  current = Nothing,
                  first = first,
                  last = last
                })
          in
              ({ model | m = inner_m }, cmd)
        Err _ ->
          ({ model | m = Error "Get error" }, Cmd.none)


type DateControlMsg =
  UpdateDate String


type Msg =
  DoNothing
  | GotRoot (Result Http.Error String)
  | GotFile (Result Http.Error String)
  | DownloadToUser
  | UpdateFirst DateControlMsg
  | UpdateLast DateControlMsg


view : Model -> Html Msg
view model =
  case model.m of
    Init -> div [] [text "init"]
    Error s -> div [] [text s]
    GettingServerFile data ->
      let
          missing_count = Debug.toString <| List.length data.next
          downloaded_count = Debug.toString <| List.length data.done
          counts = [div [] [text ("missing " ++ missing_count ++ ", downloaded " ++ downloaded_count)]]
          current =
            case data.current of
              Nothing -> []
              Just x -> [div [] [text ("downloading " ++ x)]]
          downloadDivs =
            case List.length data.done of
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


in_range d1 m1 y1 d2 m2 y2 name =
  let
    min_name = dmyToCsvName d1 m1 y1
    max_name = dmyToCsvName d2 m2 y2
  in
    name >= min_name && name <= max_name


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


modelSelectedDownloads : ModelInner -> List AFile
modelSelectedDownloads model =
  case model of
    GettingServerFile data ->
      let
        (first_year, first_month, first_day) = dateToComponents data.first.date
        (last_year, last_month, last_day) = dateToComponents data.last.date
        in_range_h = in_range first_day first_month first_year last_day last_month last_year
      in
        List.filter (\x -> in_range_h x.filename) data.done
    _ ->
      []


downloadDialog model =
  case model of
    GettingServerFile data ->
      [ button [onClick DownloadToUser] [(text "download")] ] ++
      [ text "first" ] ++
      List.map (Html.map UpdateFirst) (viewDateControl data.first) ++
      [ text "last" ] ++
      List.map (Html.map UpdateLast) (viewDateControl data.last) ++
        [div [id "files-to-download"]
          (List.map (\x -> div [] [text x]) (List.map .filename (modelSelectedDownloads model)))
        ]
    _ -> []


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

