module Main exposing (main)
import Browser
import Html exposing (..)
import Http
import Regex exposing (..)

-- My Main

type alias Model = List String


init : () -> (Model, Cmd Msg)
init _ =
  (["hello6"], Http.get { url = "/", expect = Http.expectString GotText })


parse_hrefs : String -> List String
parse_hrefs s =
  List.map (Maybe.withDefault "") (flattenList (List.map .submatches (find hrefs_regex s)))


hrefs_regex =
  Maybe.withDefault Regex.never (Regex.fromString "href=\"([^\"])\"")


flattenList : List (List a) -> List a
flattenList l =
  case l of
    [] -> []
    ((x :: z) :: y) -> x :: (flattenList (z :: y))
    [] :: y -> flattenList y


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Nothing -> (model, Cmd.none)
    GotText result ->
      case result of
        Ok something ->
          (parse_hrefs something, Cmd.none)
        Err _ ->
          (["Get error"], Cmd.none)


type Msg =
  Nothing
  | GotText (Result Http.Error String)


view : Model -> Html Msg
view model =
  div [] (List.map text model)


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

