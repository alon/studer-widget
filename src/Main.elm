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

-- My Main


type alias AFile = { filename : String, content : String }


type alias DateControlModel =
  -- todo: Maybe'fy
  { date: String }


type Model =
  Init
  | GettingServerFile {
      next : (List String),
      current : Maybe String,
      done : (List AFile),
      first : DateControlModel,
      last : DateControlModel
    }
  | Error String


init : () -> (Model, Cmd Msg)
init _ =
  (Init, Http.get { url = "/", expect = Http.expectString GotRoot })


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


download : Model -> (Model, Cmd Msg)
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
tar files =
  let
      transform = \f -> ({ defaultFileRecord | filename = f.filename }, StringData f.content)
      data = List.map transform files
  in
    createArchive data


updateDateControl : DateControlMsg -> DateControlModel -> DateControlModel
updateDateControl msg model =
  case msg of
    UpdateDate date -> { model | date = (Debug.log "new date" date) }


defaultDateControlModel =
  { date = "2019-01-01" }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    DoNothing -> (model, Cmd.none)
    UpdateFirst submsg ->
      case model of
        GettingServerFile data ->
          (GettingServerFile { data | first = (updateDateControl submsg data.first ) }, Cmd.none)
        _ ->
          (model, Cmd.none) -- and error??
    UpdateLast submsg ->
      case model of
        GettingServerFile data ->
          (GettingServerFile { data | last = (updateDateControl submsg data.last ) }, Cmd.none)
        _ ->
          (model, Cmd.none) -- and error??
    DownloadToUser ->
      case model of
        GettingServerFile data ->
          (model, (Download.bytes "test.tar" "application/x-tar" (tar data.done)))
        _ ->
          (model, Cmd.none) -- TODO - show an error to the user
    GotFile result ->
      case result of
        Ok content ->
          case model of
            GettingServerFile data ->
              case data.current of
                Just current ->
                  let
                    newmodel = GettingServerFile { data | done = ({ filename = current, content = content } :: data.done), current = Nothing }
                  in
                    download newmodel
                _ -> (Error "another unexpected case", Cmd.none)
            _ -> (Error "unexpected endcase, how do I prevent this at compile time?", Cmd.none)
        Err _ ->
          case model of
            GettingServerFile data ->
              (Error ("error downloading " ++ (Debug.toString data.current)), Cmd.none)
            _ ->
              (Error "error downloading and not in GettingServerFile, elm-help!", Cmd.none)
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
          in
              download (GettingServerFile {
                done = [],
                next = csvs,
                current = Nothing,
                first = first,
                last = last
              })
        Err _ ->
          (Error "Get error", Cmd.none)


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
  case model of
    Init -> div [] [text "init"]
    Error s -> div [] [text s]
    GettingServerFile data ->
      div []
        ([div [] [text "missing"]] ++
        List.map (\x -> div [] [text x]) data.next ++
        [div [] [text "downloaded"]] ++
        List.map (\x -> div [] [text ("downloaded " ++ (x.filename))]) data.done ++
        [div [] [text (Debug.toString data.current)]] ++
        case List.length data.done of
          0 -> []
          _ -> downloadDialog model
        )


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


downloadDialog model =
  case model of
    GettingServerFile data ->
      [ button [onClick DownloadToUser] [(text "download")] ] ++
      [ text "first" ] ++
      List.map (Html.map UpdateFirst) (viewDateControl data.first) ++
      [ text "last" ] ++
      List.map (Html.map UpdateLast) (viewDateControl data.last) ++
        let
          (first_year, first_month, first_day) = dateToComponents data.first.date
          (last_year, last_month, last_day) = dateToComponents data.last.date
          in_range_h = in_range first_day first_month first_year last_day last_month last_year
        in
            [div [id "files-to-download"]
              (List.map (\x -> div [] [text x]) (List.filter in_range_h (List.map .filename data.done)))
            ]
    _ -> []


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

