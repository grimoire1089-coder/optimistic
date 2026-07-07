# Initial Lapis Encyclopedia Registration

Status: implemented.

Main scene now has `MainSceneInitialEncyclopediaRegistrationModule`.
It registers `res://Data/Items/Tools/Lapis_001.tres` after entering the main scene.

The registration uses `FoodEncyclopedia.register_initial_item_discovered()` so it unlocks the item silently without startup notice or SFX.

This keeps Lapis visible in the encyclopedia because Robin owns it from the beginning.
