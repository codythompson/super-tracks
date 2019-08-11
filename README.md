# TODO NOTES

- implement track switching
    - show switch overlay when switch is tapped
    - populate switch overlay

## UIObj

- new UIObjPointerEvent type for pressing and releasing on same UIObj

## pathing

- switch diagrams and overlays that are relative to current direction of train
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

- Power up that lets you pick left or right and switches will be automatically switched. Maybe this shouldn't be a power up and you should just always swipe left or right to dictate the next switch move