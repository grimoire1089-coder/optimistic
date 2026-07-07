# Loading Task Modules

## Rule

`LoadingScene.gd` is the entrance for loading.
Concrete preload work should be added as child task modules under `TaskModules`.

## Current module layout

```text
Scenes/Boot/LoadingScene.tscn
  LoadingScene
    TaskModules
      LoadingShopCacheTaskModule
```

```text
Scripts/Scenes/Boot/Modules/
  LoadingTaskModule.gd
  LoadingShopCacheTaskModule.gd
```

## How to add a new loading item

1. Create `LoadingSomethingTaskModule.gd` under `Scripts/Scenes/Boot/Modules/`.
2. Extend `res://Scripts/Scenes/Boot/Modules/LoadingTaskModule.gd` by path.
3. Set `task_id`, `display_name`, and `weight` in `_ready()`.
4. Put the preload/cache work in `run_task(_context)`.
5. Add a child node under `TaskModules` in `Scenes/Boot/LoadingScene.tscn`.
6. Keep each task small and one-shot. Do not use `_process()` inside loading task modules.

## Important implementation note

Do not type `LoadingScene.gd` with `Array[LoadingTaskModule]`.
Godot may fail to resolve the global class during parse.
Use `Array[Node]` plus `has_method()` / `call()` in `LoadingScene.gd`.

## Current first task

`LoadingShopCacheTaskModule.gd` runs:

```gdscript
ShopRuntimeCache.prepare_default_database()
```

## Next candidates

1. Confirm the latest red-error fix in Godot.
2. Add an audio preload task if BGM or SFX has first-play stutter.
3. Add an encyclopedia cache task if encyclopedia unlocks still cause FPS drops.
4. Add a texture/icon preload task only for assets that actually stutter.

## Performance rules

- Loading tasks are one-shot.
- Avoid scanning the whole project.
- Prefer explicit resource lists or existing databases.
- Keep `LoadingScene.gd` thin.
- Add concrete work as modules.
