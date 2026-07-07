# Fixed Material and Misc Encyclopedia Pages

Status: implemented.

Material and Misc encyclopedia pages no longer use `HSplitContainer`.
They now use a fixed `Control` root with anchored left and right panels.

This removes the draggable boundary line from the new tabs.

`EncyclopediaFixedHalfLayoutModule.gd` was also updated to include `MaterialPage` and `MiscPage` so runtime fixed-layout support covers all current item tabs.
