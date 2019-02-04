module Main exposing (main)
import Browser
import Html exposing (..)

-- My Main

type alias Model = String


init : Model
init = "hello"


update : Msg -> Model -> Model
update msg model =
  model


type Msg =
  Nothing


view : Model -> Html Msg
view model =
  div [] [ text model ]


main =
  Browser.sandbox { init = init, update = update, view = view }

