# Robin Item Creator

Godot editor-only item creation helper scaffold.

This folder is intentionally minimal.

Current scope:

- Adds an editor plugin entry.
- Adds a simple bottom panel placeholder named `Robin Item Creator`.
- Reserves a modules folder for future save, scan, validation, effect, tag, and prompt helpers.

Not included yet:

- No file save logic.
- No existing item/resource mutation.
- No automatic database sync.
- No shop or recipe updates.

Planned module split:

- `modules/ItemCreatorSaveModule.gd`
- `modules/ItemCreatorScanModule.gd`
- `modules/ItemCreatorValidationModule.gd`
- `modules/ItemCreatorEffectModule.gd`
- `modules/ItemCreatorTagModule.gd`
- `modules/ItemCreatorPromptModule.gd`
