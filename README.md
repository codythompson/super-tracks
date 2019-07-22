# TODO NOTES

## pathing

- BUG NOTE: exit discrepancies between i and j. Need to investigate further
- Track graph needs a method that will return a new tile coordinate given a speed (non directional) and a desired turn (left, right, or none)
  - will path toward desired exit (ignores desired turn if only one exit)

## drawable

- Figure out the best way to deal with custom rotations/offsets/handles per image in a tileset (support commented out case in DbgObjs.rogue)

## Screen

- change GameState from extending a state to extendinga screen


# misc ideas

- When doing 90deg world rotations, some sort of time warp/dilation effect gives the player a subtle advantage/disadvantage over enemies

- track switch animtions in different worlds/eras
    - wild west - switch sign shot with gun
    - modern - electrity animation along a wire (or maybe a satellite)
    - space - light beams? or laser blasters :)