# Vehicle assets

Imported third-party models used by the city traffic and driveable vehicles.

## PSX cars (`psx/`)

Source: [GGBot on itch.io](https://ggbot.itch.io/) — "PSX Style Cars (August 2023)".
Only the `.obj`, `.mtl` and referenced texture `.png` files were copied; the
original `.blend` sources and unused textures were left in the asset library.
Check the original pack's own license before shipping a commercial product.

Car models are ~6 units long in source space; `vehicle.gd` scales them to the
city's 4.5–5 m road scale. Forward axis is +Z in the source OBJ and is rotated
to Godot's forward (-Z) when instantiated.
