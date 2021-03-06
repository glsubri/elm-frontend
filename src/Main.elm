module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Cmd exposing (initWith, updateWith, withCmd, withNoCmd)
import Html
import Page.Authenticate as Auth
import Page.Home as Home
import Page.Logout as Quit
import Picasso.Navigation as NavUI
import Route exposing (Route)
import Session exposing (Session)
import Url



-- MODEL


type alias Model =
    { page : PageModel
    , navi : NavUI.Model
    }


type PageModel
    = AuthModel Auth.Model
    | HomeModel Home.Model
    | QuitModel Quit.Model



-- MODEL EMBEDDING


{-| Given a certain model that displays a page, and a mapping from a model to
a page, produces a function that makes it possible to update the page of the
tuple as needed.

This is in essence like a function to partially map a record and keep its
untouched values.

-}
embed : Model -> (a -> PageModel) -> a -> Model
embed model toModel =
    \m ->
        let
            pageModel =
                toModel m
        in
        { model
            | page = pageModel
            , navi = model.navi |> NavUI.withSession (toSession pageModel)
        }


{-| Embeds navigation model changes into an existing model instance.
-}
embedNav : Model -> (a -> NavUI.Model) -> a -> Model
embedNav model toModel =
    \m ->
        let
            navModel =
                toModel m
        in
        { model | navi = navModel }


{-| Returns the Session associated with the current model. This information
will be passed around the different sub-models and acts as the shared
information for the lifetime of the application.
-}
toSession : PageModel -> Session
toSession model =
    case model of
        AuthModel m ->
            m.session

        HomeModel m ->
            m.session

        QuitModel m ->
            m.session


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Message )
init _ url key =
    let
        session =
            Session.guest key

        start =
            \model ->
                { page = HomeModel model
                , navi = NavUI.init Route.Home session
                }
    in
    initWith
        HomeMessage
        start
        (Home.init session)



-- VIEW


view : Model -> Browser.Document Message
view model =
    let
        header =
            NavUI.view model.navi
                |> Html.map NavUIMessage

        contents =
            case model.page of
                AuthModel authModel ->
                    Auth.view authModel
                        |> List.map (Html.map AuthMessage)

                HomeModel homeModel ->
                    Home.view homeModel
                        |> List.map (Html.map HomeMessage)

                QuitModel quitModel ->
                    Quit.view quitModel
                        |> List.map (Html.map never)
    in
    { title = "heig-PRO-b04 | Live polls"
    , body = header :: contents
    }



-- UPDATE


type Message
    = ChangedUrl Url.Url
    | ClickedLink Browser.UrlRequest
    | NavUIMessage NavUI.Message
    | HomeMessage Home.Message
    | AuthMessage Auth.Message


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    let
        session =
            toSession model.page
    in
    case ( msg, model.page ) of
        ( NavUIMessage navMsg, _ ) ->
            updateWith
                NavUIMessage
                (embedNav model identity)
                NavUI.update
                navMsg
                model.navi

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( ClickedLink request, _ ) ->
            case request of
                Browser.Internal url ->
                    model
                        |> withCmd
                            [ Nav.pushUrl
                                (Session.navKey session)
                                (Url.toString url)
                            ]

                Browser.External href ->
                    model |> withCmd [ Nav.load href ]

        ( AuthMessage authMsg, AuthModel authModel ) ->
            updateWith
                AuthMessage
                (embed model AuthModel)
                Auth.update
                authMsg
                authModel

        ( HomeMessage homeMsg, HomeModel homeModel ) ->
            updateWith
                HomeMessage
                (embed model HomeModel)
                Home.update
                homeMsg
                homeModel

        ( _, _ ) ->
            model
                |> withNoCmd


subscriptions : Model -> Sub Message
subscriptions _ =
    Sub.none


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Message )
changeRouteTo route model =
    let
        newRoute =
            route |> Maybe.withDefault Route.Home

        newModel =
            { model | navi = model.navi |> NavUI.withRoute newRoute }

        session =
            toSession model.page
    in
    case route of
        Nothing ->
            initWith
                HomeMessage
                (embed newModel HomeModel)
                (Home.init session)

        Just Route.Home ->
            initWith
                HomeMessage
                (embed newModel HomeModel)
                (Home.init session)

        Just Route.Login ->
            initWith
                AuthMessage
                (embed newModel AuthModel)
                (Auth.initLogin session)

        Just Route.Registration ->
            initWith
                AuthMessage
                (embed newModel AuthModel)
                (Auth.initRegistration session)

        Just Route.Logout ->
            initWith
                never
                (embed newModel QuitModel)
                (Quit.init session)



-- APPLICATION


main : Program () Model Message
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlRequest = ClickedLink
        , onUrlChange = ChangedUrl
        }
