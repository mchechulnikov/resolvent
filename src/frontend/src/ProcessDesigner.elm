module ProcessDesigner exposing (..)

import Controls
import Css exposing (..)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (attribute, css)
import Html.Styled.Events exposing (..)
import Json.Decode as Decode
import List.Extra as List
import Utils exposing (boolToString, updateIfTrue, onStd, onWithoutDef, onWithoutProp)


type Msg
    = Idle
    | ToggleMode Mode
    | TempIdRequested (Int -> Msg)
    | NewProcess Process Int
    | NewItem Process ProcessItem Int Int
    | NewItemSlot Process
    | DragProcessItemStart DraggingProcessItemState
    | DragProcessItemEnd
    | DropProcessItem DropProcessItemTarget
    | DragEmptyItemStart DraggingEmptyItemState
    | DragEmptyItemEnd
    | DropEmptyItem
    | DragProcessStart DraggingProcessState
    | DragProcessEnd
    | DragTargetOnDraggableArea Bool
    | DropProcess


type alias Model =
    { processes : List Process
    , mode : Mode
    , draggingProcessItemState : Maybe DraggingProcessItemState
    , draggingEmptyItemState : Maybe DraggingEmptyItemState
    , draggingProcessState : Maybe DraggingProcessState
    }


type alias Process =
    { id : String
    , name : String
    , items : List (Maybe ProcessItem)
    }


type alias ProcessItem =
    { id : String
    , name : String
    , description : String
    }


type alias DraggingProcessItemState =
    { process : Process
    , item : ProcessItem
    , itemIndex : Int
    , hasTargeted : Bool
    }


type alias DraggingEmptyItemState =
    { process : Process
    , itemIndex : Int
    , hasTargeted : Bool
    }


type alias DraggingProcessState =
    { process : Process
    , hasTargeted : Bool
    }


type Mode
    = Viewer
    | Editor


type DropProcessItemTarget
    = DropOnEmptySlot Process Int
    | DropOnNewSlot Process
    | DropInBin
    | DropOnAnotherProcessItem Process ProcessItem Int


type DroppableAreaMode
    = Normal
    | ReadyToReceiveProcessItem
    | ReadyToReceiveEmptyItem
    | ReadyToReceiveProcess



-- UPDATE


toggleMode : Mode -> Model -> Model
toggleMode mode model =
    { model | mode = mode }


newProcess : Int -> Process -> Model -> Model
newProcess tempId process model =
    addProcess { process | id = String.fromInt tempId } model


addProcess : Process -> Model -> Model
addProcess process model =
    { model | processes = List.append model.processes [ process ] }


newItemToProcess : Int -> Int -> ProcessItem -> Process -> Model -> Model
newItemToProcess tempId itemIndex item process model =
    addItemToProcess itemIndex { item | id = String.fromInt tempId } process model


addItemToProcess : Int -> ProcessItem -> Process -> Model -> Model
addItemToProcess itemIndex item process model =
    let
        update p =
            { p | items = p.items |> List.updateAt itemIndex (\_ -> Just item) }

        updatedProcesses =
            model.processes |> List.map (\p -> updateIfTrue update p (p.id == process.id))
    in
    { model | processes = updatedProcesses }


removeItemFromProcess : Int -> Process -> Model -> Model
removeItemFromProcess itemIndex process model =
    let
        update p =
            { p | items = p.items |> List.updateAt itemIndex (\_ -> Nothing) }

        updatedProcesses =
            model.processes
                |> List.map (\p -> updateIfTrue update p (p.id == process.id))
    in
    { model | processes = updatedProcesses }


dropProcessItemOn : DropProcessItemTarget -> Model -> Model
dropProcessItemOn target model =
    model.draggingProcessItemState
        |> Maybe.map
            (\{ process, item, itemIndex } ->
                case target of
                    DropOnNewSlot targetProcess ->
                        model
                            |> addItemSlot targetProcess
                            |> addItemToProcess (List.length targetProcess.items) item targetProcess
                            |> removeItemFromProcess itemIndex process

                    DropInBin ->
                        removeItemFromProcess itemIndex process model

                    DropOnEmptySlot targetProcess targetItemIndex ->
                        model
                            |> addItemToProcess targetItemIndex item targetProcess
                            |> removeItemFromProcess itemIndex process

                    DropOnAnotherProcessItem targetProcess targetItem targetItemIndex ->
                        model
                            |> addItemToProcess itemIndex targetItem process
                            |> addItemToProcess targetItemIndex item targetProcess
            )
        |> Maybe.withDefault model
        |> clearDraggingProcessItemState


addItemSlot : Process -> Model -> Model
addItemSlot process model =
    let
        update p =
            { p | items = List.append p.items [ Nothing ] }

        updatedProcesses =
            model.processes |> List.map (\p -> updateIfTrue update p (p.id == process.id))
    in
    { model | processes = updatedProcesses }


removeEmptySlot : Int -> Process -> Model -> Model
removeEmptySlot itemIndex process model =
    let
        update p =
            { p | items = p.items |> List.removeAt itemIndex }

        updatedProcesses =
            model.processes
                |> List.map (\p -> updateIfTrue update p (p.id == process.id))
    in
    { model | processes = updatedProcesses }


dropEmptyItemToBin : Model -> Model
dropEmptyItemToBin model =
    model.draggingEmptyItemState
        |> Maybe.map (\{ process, itemIndex } -> removeEmptySlot itemIndex process model)
        |> Maybe.withDefault model
        |> clearDraggingEmptyItemState


removeProcess : Process -> Model -> Model
removeProcess process model =
    { model | processes = model.processes |> List.remove process }


dropProcessToBin : Model -> Model
dropProcessToBin model =
    model.draggingProcessState
        |> Maybe.map (\{ process } -> removeProcess process model)
        |> Maybe.withDefault model
        |> clearDraggingProcessState


setDraggingProcessItemState : DraggingProcessItemState -> Model -> Model
setDraggingProcessItemState draggingState model =
    { model | draggingProcessItemState = Just draggingState }


hasProcessItemTargeted : Model -> Bool
hasProcessItemTargeted model =
    model.draggingProcessItemState
        |> Maybe.map .hasTargeted
        |> Maybe.withDefault False


clearDraggingProcessItemState : Model -> Model
clearDraggingProcessItemState model =
    { model | draggingProcessItemState = Nothing }


setDraggingEmptyItemState : DraggingEmptyItemState -> Model -> Model
setDraggingEmptyItemState draggingState model =
    { model | draggingEmptyItemState = Just draggingState }


hasEmptyItemTargeted : Model -> Bool
hasEmptyItemTargeted model =
    model.draggingEmptyItemState
        |> Maybe.map .hasTargeted
        |> Maybe.withDefault False


clearDraggingEmptyItemState : Model -> Model
clearDraggingEmptyItemState model =
    { model | draggingEmptyItemState = Nothing }


setDraggingProcessState : DraggingProcessState -> Model -> Model
setDraggingProcessState draggingState model =
    { model | draggingProcessState = Just draggingState }


hasProcessTargeted : Model -> Bool
hasProcessTargeted model =
    model.draggingProcessState
        |> Maybe.map .hasTargeted
        |> Maybe.withDefault False


clearDraggingProcessState : Model -> Model
clearDraggingProcessState model =
    { model | draggingProcessState = Nothing }


toggleTargetingOfDraggingState : Bool -> Model -> Model
toggleTargetingOfDraggingState hasTargeted model =
    { model
    | draggingProcessItemState = model.draggingProcessItemState |> Maybe.map (\s -> { s | hasTargeted = hasTargeted})
    , draggingEmptyItemState = model.draggingEmptyItemState |> Maybe.map (\s -> { s | hasTargeted = hasTargeted})
    , draggingProcessState = model.draggingProcessState |> Maybe.map (\s -> { s | hasTargeted = hasTargeted})
    }


-- ATTRS


attrDraggable mode =
    attribute "draggable" (boolToString (mode == Editor))


attrEditable mode =
    attribute "contenteditable" (boolToString (mode == Editor))


-- VIEW


view : Model -> Html Msg
view model =
    let
        droppableAreaMode =
            if model.draggingProcessItemState /= Nothing then
                ReadyToReceiveProcessItem

            else if model.draggingEmptyItemState /= Nothing then
                ReadyToReceiveEmptyItem

            else if model.draggingProcessState /= Nothing then
                ReadyToReceiveProcess

            else
                Normal

        toggleModeButton =
            let
                (label, newMode) =
                    case model.mode of
                        Viewer ->
                            ("Edit", Editor)

                        Editor ->
                            ("Back to viewer", Viewer)
            in
            Controls.viewToggle label newMode ToggleMode ((==) Viewer)
    in
    model.processes
        |> List.map (viewProcess model.mode droppableAreaMode)
        |> (\ps ->
            if model.mode == Editor then
                List.append ps [ div [ css [ displayFlex ] ] [ viewAddProcessButton model, viewBin droppableAreaMode ] ]

            else
                ps
        )
        |> List.append [ toggleModeButton ]
        |> div
            [ css
                [ overflowX scroll
                , whiteSpace noWrap
                ]
            ]

viewProcess mode droppableAreaMode process =
    let
        viewProcessItems  =
            let
                items =
                    process.items
                        |> List.filter ((/=) Nothing >> (||) (mode == Editor))
                        |> List.indexedMap
                            ( \itemIndex item ->
                                item
                                    |> Maybe.map (viewProcessItem mode process)
                                    |> Maybe.withDefault (viewEmptyItem mode droppableAreaMode process itemIndex)
                            )
            in
            if mode == Editor then
                List.append items [ viewNewSlotButton droppableAreaMode process ]

            else
                items
    in
    div
        [ css
            [ displayFlex
            , before
                [ width (rem 2)
                , minWidth (rem 2)
                , margin (rem 0.25)
                , backgroundColor (hex "#606dbc")
                , property "content" "''"
                , cursor (if mode == Editor then move else default)
                ]
            , hover
                [ backgroundColor (rgba 128 128 128 0.05)
                ]
            ]
        , onWithoutProp "dragstart" (DragProcessStart { process = process, hasTargeted = False })
        , onWithoutProp "dragend" DragProcessEnd
        , attrDraggable mode
        ]
        viewProcessItems


viewProcessItem mode process processItem =
    let
        viewName =
            div
                [ css []
                ]
                [ div
                    [ attrEditable mode
                    , css
                        [ focus [ outline none ]
                        , whiteSpace noWrap
                        ]
                    ]
                    [ text processItem.name ]
                ]

        itemIndex =
            process.items
                |> List.elemIndex (Just processItem)
                |> Maybe.withDefault 0  -- unattainable result
    in
    div
        [ css
            [ border3 (rem 0.1) solid (rgb 4 4 4)
            , margin (rem 0.5)
            , padding (rem 0.25)
            , minWidth (rem 10)
            , height (rem 3)
            , overflowX hidden
            , backgroundColor (rgb 255 255 255)
            , hover
                [ border3 (rem 0.1) solid (rgb 10 124 10)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 10 124 10)
                , cursor pointer
                ]
            , active
                [ border3 (rem 0.1) solid (rgb 26 171 26)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 26 171 26)
                , cursor pointer
                ]
            ]
        , attrDraggable mode
        , onWithoutProp "dragstart" (DragProcessItemStart (DraggingProcessItemState process processItem itemIndex False))
        , onWithoutProp "dragend" DragProcessItemEnd
        , onWithoutProp "dragenter" (DragTargetOnDraggableArea True)
        , onWithoutProp "dragleave" (DragTargetOnDraggableArea False)
        , onWithoutProp "drop" (DropProcessItem (DropOnAnotherProcessItem process processItem itemIndex))
        , onWithoutDef "dragover" Idle
        ]
        [ div
            []
            [ viewName
            ]
        ]


viewEmptyItem mode droppableAreaMode process itemIndex =
    let
        newItemName =
            "New item " ++ (String.fromInt (itemIndex + 1))

        droppableStyles =
            case droppableAreaMode of
                ReadyToReceiveProcessItem ->
                    Css.batch
                        [ border3 (rem 0.1) dashed (rgb 15 103 15)
                        , backgroundColor (rgb 216 255 211)
                        , color (rgb 13 110 13)
                        , opacity (num 0.5)
                        ]

                _ ->
                    Css.batch
                        [ border3 (rem 0.1) solid (rgb 255 255 255)
                        , opacity (num 0.25)
                        ]
    in
    div
        [ css
            [ droppableStyles
            , margin (rem 0.5)
            , padding (rem 0.25)
            , minWidth (rem 10)
            , height (rem 3)
            , hover
                [ border3 (rem 0.1) solid (rgb 15 103 15)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 13 110 13)
                , cursor pointer
                , opacity (num 0.5)
                ]
            , active
                [ border3 (rem 0.1) solid (rgb 26 171 26)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 26 171 26)
                , cursor pointer
                , opacity (num 0.85)
                ]
            ]
        , onClick (TempIdRequested (NewItem process { id = "", name = newItemName, description = "" } itemIndex))
        , onWithoutDef "dragover" Idle
        , attrDraggable mode
        , onStd "drop" (DropProcessItem (DropOnEmptySlot process itemIndex))
        , onWithoutProp "dragstart" (DragEmptyItemStart { process = process, itemIndex = itemIndex, hasTargeted = False  })
        , onWithoutProp "dragend" DragEmptyItemEnd
        , onStd "dragenter" (DragTargetOnDraggableArea True)
        , onStd "dragleave" (DragTargetOnDraggableArea False)
        ]
        [ text "EMPTY" ]


viewNewSlotButton droppableAreaMode process =
    let
        droppableStyles =
            case droppableAreaMode of
                ReadyToReceiveProcessItem ->
                    Css.batch
                        [ border3 (rem 0.1) dashed (rgb 15 103 15)
                        , backgroundColor (rgb 216 255 211)
                        , color (rgb 13 110 13)
                        , opacity (num 0.5)
                        ]

                _ ->
                    Css.batch
                        [ border3 (rem 0.1) dashed (rgb 4 4 4)
                        , opacity (num 0.25)
                        ]
    in
    div
        [ css
            [ droppableStyles
            , margin (rem 0.5)
            , padding (rem 0.25)
            , minWidth (rem 10)
            , height (rem 3)
            , hover
                [ backgroundColor (rgb 216 255 211)
                , color (rgb 13 110 13)
                , cursor pointer
                , opacity (num 0.5)
                ]
            , active
                [ border3 (rem 0.1) solid (rgb 26 171 26)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 26 171 26)
                , cursor pointer
                , opacity (num 0.85)
                ]
            ]
        , onClick (NewItemSlot process)
        , onWithoutDef "dragover" Idle
        , onStd "drop" (DropProcessItem (DropOnNewSlot process))
        , onStd "dragenter" (DragTargetOnDraggableArea True)
        , onStd "dragleave" (DragTargetOnDraggableArea False)
        ]
        [ text "➕" ]


viewAddProcessButton model =
    let
        processesCount =
            List.length model.processes

        newProcessName =
            "New item " ++ (String.fromInt (processesCount + 1))
    in
    div
        [ css
            [ border3 (rem 0.1) dashed (rgb 4 4 4)
            , margin (rem 0.5)
            , padding (rem 0.25)
            , width (rem 20)
            , height (rem 3)
            , opacity (num 0.25)
            , hover
                [ border3 (rem 0.1) solid (rgb 15 103 15)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 13 110 13)
                , cursor pointer
                , opacity (num 0.5)
                ]
            , active
                [ border3 (rem 0.1) solid (rgb 26 171 26)
                , backgroundColor (rgb 216 255 211)
                , color (rgb 26 171 26)
                , cursor pointer
                , opacity (num 0.85)
                ]
            ]
        , onClick (TempIdRequested (NewProcess (Process newProcessName newProcessName [])))
        ]
        [ text "➕" ]


viewBin : DroppableAreaMode -> Html Msg
viewBin droppableAreaMode =
    let
        droppableStyles =
            let
                droppableReadyStyles =
                    Css.batch
                        [ border3 (rem 0.1) dashed (rgb 105 0 24)
                        , backgroundColor (rgb 255 211 216)
                        , color (rgb 105 0 24)
                        , opacity (num 0.5)
                        , display block
                        ]
            in
            case droppableAreaMode of
                ReadyToReceiveProcessItem ->
                    droppableReadyStyles

                ReadyToReceiveEmptyItem ->
                    droppableReadyStyles

                ReadyToReceiveProcess->
                    droppableReadyStyles

                _ ->
                    Css.batch
                        [ border3 (rem 0.1) dashed (rgb 4 4 4)
                        , opacity (num 0.25)
                        , display none
                        ]

        dropMsg =
            case droppableAreaMode of
                Normal ->
                    Idle

                ReadyToReceiveProcessItem ->
                    DropProcessItem DropInBin

                ReadyToReceiveEmptyItem ->
                    DropEmptyItem

                ReadyToReceiveProcess ->
                    DropProcess
    in
    div
        [ css
            [ droppableStyles
            , position fixed
            , bottom (rem 0)
            , right (rem 0)
            , margin (rem 0.5)
            , padding (rem 0.25)
            , width (vw 25)
            , height (vh 25)
            ]
        , onWithoutDef "dragover" Idle
        , onStd "drop" dropMsg
        , onStd "dragenter" (DragTargetOnDraggableArea True)
        , onStd "dragleave" (DragTargetOnDraggableArea False)
        ]
        [ text "🗑️" ]
