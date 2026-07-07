# Material and Misc Encyclopedia Tabs

Status: implemented.

Added two encyclopedia page scenes:

- `Scenes/UI/Encyclopedia/Pages/MaterialEncyclopediaPage.tscn`
- `Scenes/UI/Encyclopedia/Pages/MiscEncyclopediaPage.tscn`

Updated category modules to include:

- `materials` / 素材
- `misc` / 雑貨

Updated `EncyclopediaOverlay.tscn` to attach `MaterialPage` and `MiscPage` to the tab container.

The overlay also scans future directories:

- `res://Data/Items/Materials`
- `res://Data/Items/Misc`

No existing tabs were removed.
