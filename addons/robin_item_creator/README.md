# Robin Item Creator

Godot editor-only item creation helper scaffold.

This folder is intentionally minimal.

Current scope:

- Adds an editor plugin entry.
- Adds a bottom panel named `Robin Item Creator`.
- Adds an input form and preview.
- Adds validation messages for display name, item ID, save path, price, and basic need values.
- Can create a single `FoodItemData.tres` from the form.
- Creates missing target folders when saving.
- Never overwrites an existing resource.
- Reserves a modules folder for future scan, effect, tag, and prompt helpers.

Not included yet:

- No existing item/resource mutation.
- No automatic database sync.
- No shop or recipe updates.
- No tag editing yet.
- No icon picker yet.

Planned module split:

- `modules/ItemCreatorScanModule.gd`
- `modules/ItemCreatorEffectModule.gd`
- `modules/ItemCreatorTagModule.gd`
- `modules/ItemCreatorPromptModule.gd`
