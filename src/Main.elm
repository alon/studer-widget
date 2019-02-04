module Main exposing (main)
import Browser
import Html exposing (..)
import Http

-- My Main

type alias Model = String


init : () -> (Model, Cmd Msg)
init _ =
  ("hello5", Http.get { url = "/", expect = Http.expectString GotText })


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Nothing -> (model, Cmd.none)
    GotText result ->
      case result of
        Ok something -> (something, Cmd.none)
        Err _ -> ("Get error", Cmd.none)


type Msg =
  Nothing
  | GotText (Result Http.Error String)


view : Model -> Html Msg
view model =
  div [] [ text model ]


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

