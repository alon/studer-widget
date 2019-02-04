module Main exposing (main)
import Browser
import Html exposing (..)
import Http

-- My Main

type alias Model = String


init : () -> (Model, Cmd Msg)
init _ =
  ("hello", Cmd.none)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  (model, Cmd.none)


type Msg =
  Nothing


view : Model -> Html Msg
view model =
  div [] [ text model ]


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


main =
  Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

