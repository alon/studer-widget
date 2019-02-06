module Main exposing (main)
import Browser
import Html exposing (..)
import Http
import Regex exposing (..)

-- My Main


type alias AFile = { filename : String, content : String }


type Model =
  Init
  | Downloading {
      next : (List String),
      current : Maybe String,
      done : (List AFile)
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
      (Debug.log s (List.map .submatches (find hrefs_regex s))))


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
    Downloading data ->
      case data.next of
        first :: rest ->
          (Downloading { next = rest, current = Just first, done = data.done },
           Http.get { url = first, expect = Http.expectString GotFile }
          )
        [] ->
          (model, Cmd.none)
    _ -> (model, Cmd.none)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    DoNothing -> (model, Cmd.none)
    GotFile result ->
      case result of
        Ok content ->
          case model of
            Downloading data ->
              case data.current of
                Just current ->
                  let
                    newmodel = Downloading { data | done = ({ filename = current, content = content } :: data.done), current = Nothing }
                  in
                    download newmodel
                _ -> (Error "another unexpected case", Cmd.none)
            _ -> (Error "unexpected endcase, how do I prevent this at compile time?", Cmd.none)
        Err _ ->
          case model of
            Downloading data ->
              (Error ("error downloading " ++ (Debug.toString data.current)), Cmd.none)
            _ ->
              (Error "error downloading and not in Downloading, elm-help!", Cmd.none)
    GotRoot result ->
      case result of
        Ok something ->
          let
              parsed = parse_hrefs something
          in
              download (Downloading { done = [], next = parsed, current = Nothing })
        Err _ ->
          (Error "Get error", Cmd.none)


type Msg =
  DoNothing
  | GotRoot (Result Http.Error String)
  | GotFile (Result Http.Error String)


view : Model -> Html Msg
view model =
  case model of
    Init -> div [] [text "init"]
    Error s -> div [] [text s]
    Downloading data ->
      div []
        ([div [] [text "missing"]] ++
        List.map (\x -> div [] [text x]) data.next ++
        [div [] [text "downloaded"]] ++
        List.map (\x -> div [] [text ("downloaded " ++ (x.filename))]) data.done ++
        [div [] [text (Debug.toString data.current)]]
        )


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

