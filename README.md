# TODO NOTES

## pathing

- Track graph needs a method that will return a new tile coordinate given a speed (non directional) and a desired turn (left, right, or none)
  - will path toward desired exit (ignores desired turn if only one exit)

## drawable

- need a class that has information about how to draw an image
    - needs and offset (currently built into game obj)
    - needs scale relative to a tile (i.e. if tiles are 100x100, a tileScale of 1.5x1.5 would draw a 100x100 image at 150x150)
