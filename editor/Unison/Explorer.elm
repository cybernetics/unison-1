module Unison.Explorer where

import Elmz.Layout (Layout,Region)
import Elmz.Layout as Layout
import Elmz.Moore (Moore)
import Elmz.Moore as M
import Elmz.Movement as Movement
import Elmz.Signal as Signals
import Graphics.Element (Element)
import Graphics.Element as E
import Graphics.Input.Field as Field
import Keyboard
import List
import List ((::))
import Maybe
import Mouse
import Signal
import Unison.Styles as Styles

{-|

While CLOSED, on click/enter, if scope is currently defined, enter state OPEN
  * generates a popup immediately below the currently selected scope
  * popup has an input box and a list of search results
While OPEN
  * if on tablet/mobile and valid completions is small, avoid showing input box
    unless user clicks
  * arrow keys do not manipulate scope, they navigate around the explorer
    * similar behavior to scope manipulation, mouse movement cancels
  * clicks outside explorer popup cancel the edit
  * clicks inside input box handled by input box
  * hovers inside explorer pop up previews
  * click/enter of search result exits to CLOSED with a pending edit
  * display goal type
  * display current type
-}

todo : a
todo = todo

type alias S v =
  { isKeyboardOpen : Bool
  , prompt : String
  , goal : Element
  , current : Element
  , input : Field.Content
  , searchbox : Signal.Channel Field.Content
  , focus : Region
  , overall : Region
  , completions : List (Element,v)
  , invalidCompletions : List Element }

listSelection : Signal (Int,Int) -> Signal Movement.D1 -> Signal (Layout (Maybe Int)) -> Signal (Maybe Int)
listSelection mouse upDown l =
  let reset = mouse
      base l (x,y) = case Layout.atPoint l { x = x, y = y } of
        h :: _ -> (l, h)
        _ -> (l, Nothing)
      indexOk ctx i = Layout.exists ((==) i) ctx
      modify f (ctx,i) =
        let i' = case i of
          Nothing -> Nothing
          Just i -> if indexOk ctx (Just (f i)) then Just (f i) else Just i
        in (ctx, i')
      mover = { increment = modify (\i -> i + 1), decrement = modify (\i -> i - 1) }
  in Movement.moveD1 mover reset (Signal.map2 base l mouse) upDown
     |> Signal.map (Maybe.map snd)
     |> Signals.flattenMaybe

highlightSelection : Signal (Layout (Maybe Int)) -> Signal (Maybe Int) -> Signal Element
highlightSelection l i =
  let layer l i = case i of
    Nothing -> E.empty
    Just i -> case Layout.region (\_ _ -> True) identity l (Just i) of
      (_, region) :: _ -> Styles.selection l region
      _ -> E.empty
  in Signal.map2 layer l i

autocomplete : S v -> Layout (Maybe Int)
autocomplete s =
  let ok = not (List.isEmpty s.completions)
      statusColor = if ok then Styles.okColor else Styles.notOkColor
      fld = Field.field (Styles.autocomplete ok)
                        (Signal.send s.searchbox)
                        s.prompt
                        s.input
      insertion = Styles.carotUp 7 statusColor
      fldWithInsertion = E.flow E.down [E.spacer 1 1, E.flow E.right [E.spacer 8 0, insertion], fld]
      status = Layout.above Nothing (Layout.embed Nothing s.goal)
                                    (Layout.embed Nothing s.current)
      renderCompletion i (e,v) = Layout.embed (Just i) e
      invalids = List.map (Layout.embed Nothing) s.invalidCompletions
      box = Layout.above Nothing
        (Layout.embed Nothing fldWithInsertion)
        (Styles.verticalCells Nothing E.empty (status :: List.indexedMap renderCompletion s.completions
                                               `List.append` invalids))
      boxTopLeft = { x = s.focus.topLeft.x, y = s.focus.topLeft.y + s.focus.height }
      h = boxTopLeft.y + E.heightOf (Layout.element box)
  in Layout.container Nothing s.overall.width h boxTopLeft box

explorer : Signal (Int,Int) -> Signal Movement.D1 -> Signal (Maybe (S v)) -> Signal (Maybe (Element, v))
explorer mouse upDown s =
  let base : Signal (Layout (Maybe Int))
      base = Signals.fromMaybe (Signal.constant (Layout.empty Nothing))
                               (Signals.justs (Signal.map (Maybe.map autocomplete) s))
      selection : Signal (Maybe Int)
      selection = listSelection mouse upDown base
      highlight : Signal Element
      highlight = highlightSelection base selection
      selection' =
        let f ex s i hl =
          i `Maybe.andThen` (\i ->
          s `Maybe.andThen` (\s ->
            Maybe.map (\(_,v) -> (E.layers [Layout.element ex, hl], v)) (safeIndex i s.completions)))
        in Signal.map4 f base s selection highlight
  in selection'

safeIndex : Int -> List a -> Maybe a
safeIndex i l = case List.drop i l of
  h :: _ -> Just h
  _ -> Nothing

blah =
  let names = ["Alice", "Allison", "Bob", "Burt", "Carol", "Chris", "Dave", "Donna", "Eve", "Frank"]
  in todo