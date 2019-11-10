# NEARTERM TODOS

- touch/player controlled camera (makes it easier to switch switches)
- need a better way to visualize the switches
    - icon for non active exits separate from active exit icon
- notion of a level (has a start and an end)
- Simple AI
    1. first more than one game obj
    2. ai can switch it's own tracks (maybe only supa powaful enemies)
- bullets?

# LONGTERM TODOS

## EventManager
- allow for multiple tags (return a EventListenerPointer object that allows for removal from multple tag listener arrays)
- allow for tag-less game obj event listeners (fires for every tag)
    - maybe it has a black list of tags
- try to generalized GameObj events (allow for arbitrary event types)
- figure out a good way to make TilePointerEvent more like a TileEvent (not pointer specific)

## SwitchState

- support for 4 exitPairs
- indicate with exitPair is currently Active
- switch diagrams and overlays that are relative to current direction of train

## UIObj

- new UIObjPointerEvent type for pressing and releasing on same UIObj
- some mechanism for blocking touches from passing through to a UIObj that is under other UIObjs

## pathing

- Mover that doesn't follow tracks/graph
- GameObj components (location, speed, angle) movers only act on objs with components they recognize and appropriate tags

## drawable

- Figure out the best way to deal with custom rotations/offsets/handles per image in a tileset (support commented out case in DbgObjs.rogue)


# misc game design ideas

- When doing 90deg world rotations, some sort of time warp/dilation effect gives the player a subtle advantage/disadvantage over enemies

- track switch animtions in different worlds/eras
    - wild west - switch sign shot with gun
    - modern - electrity animation along a wire (or maybe a satellite)
    - space - light beams? or laser blasters :)

- swipe control - screen is split into two different sections. swipe left, right or double tap? on lower section for closest switch. Upper section for next closest switch.
- Power up that lets you pick left or right and switches will be automatically switched. Maybe this shouldn't be a power up and you should just always swipe left or right to dictate the next switch move