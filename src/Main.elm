module Main exposing (main)
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
  { day: String, month: String, year: String }


defaultDateControlModel =
  { day = "1", month = "1", year = "2019" }


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
               url = (Debug.log "get url" (first ++ "#bla")),
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
    UpdateDay day -> { model | day = day }
    UpdateMonth month -> { model | month = month }
    UpdateYear year -> { model | year = year }


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
              csvs = List.filter (\s -> String.endsWith ".csv" (String.toLower s)) parsed
          in
              download (GettingServerFile { done = [], next = csvs, current = Nothing, first = defaultDateControlModel, last = defaultDateControlModel })
        Err _ ->
          (Error "Get error", Cmd.none)


type DateControlMsg =
  UpdateDay String
  | UpdateMonth String
  | UpdateYear String


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


to_csv_name d m y =
  "bla_" ++ y ++ m ++ d ++ ".csv"


in_range d1 m1 y1 d2 m2 y2 name =
  let
    min_name = to_csv_name d1 m1 y1
    max_name = to_csv_name d2 m2 y2
  in
    name >= min_name && name <= max_name


viewDateControl : DateControlModel -> List (Html DateControlMsg)
viewDateControl model =
  [ input [ placeholder "day", value model.day, onInput UpdateDay ] [] ] ++
  [ input [ placeholder "month", value model.month, onInput UpdateMonth ] [] ] ++
  [ input [ placeholder "year", value model.year, onInput UpdateYear ] [] ]


downloadDialog model =
  case model of
    GettingServerFile data ->
      [ button [onClick DownloadToUser] [(text "download")] ] ++
      List.map (Html.map UpdateFirst) (viewDateControl data.first) ++
      List.map (Html.map UpdateLast) (viewDateControl data.last) ++
        let
          first = data.first
          last = data.last
          in_range_h = in_range first.day first.month first.year last.day last.month last.year
        in
          List.map text (List.filter in_range_h (List.map .filename data.done))
    _ -> []


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

