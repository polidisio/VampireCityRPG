# Code Review Report: VampireCityRPG
Generated: 2026-10-26T00:21:48.241632

I have a complete picture. Here's my review.

---

# Code Review — VampireCityRPG

**Scope:** `scripts/` (28 files, ~2,900 lines), `tests/` (14 files), `tools/` (3 Python) — read from git `HEAD`.

> ⚠️ **Working tree note:** every tracked file is currently deleted from the working directory (`git status` shows ` D` for the whole repo) while `scripts/`, `tests/`, `tools/` exist as empty directories. I reviewed the code at `HEAD` without modifying the tree. If this deletion is unintentional, `git restore .` recovers it.

**Overall:** This is clean, well-factored game code — clear separation of data (`CharacterData`/`ItemData`/`Pacts`) from systems (`BattleSystem`, `level.gd`) from UI, consistent naming, no `eval`, no network/shell-out, no credential handling, and no untrusted input. **There are no security vulnerabilities.** The issues below are correctness, robustness and maintainability.

---

## 1. CRITICAL (must fix)

### C1 — A failed save write silently destroys all meta-progress
**`scripts/save_game.gd:19-20`**

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

Two compounding defects:

1. **`FileAccess.open` returns `null` on failure** (disk full, permissions, read-only `user://`). `f.store_string` on `null` is a hard runtime error — and the file has *already* been truncated to zero bytes by then.
2. **The write is not atomic.** `FileAccess.open(..., WRITE)` truncates the target immediately. If the process is killed mid-`store_string` (alt-tab, crash, OS shutdown), `save.json` is a partial or empty JSON string.

The consequence is severe: `load_game()` (`save_game.gd:26-28`) returns `[]` for any non-dictionary payload, and `level.gd:59` reads that as *"no save exists"* → `_show_class_select()`. The player's **Essencia, altar levels, streak, and quests are gone with no recovery path** — not just the run.

**Fix** — write to a temp file and rename (atomic on POSIX), and never touch the live file unless the write succeeded:

```gdscript
var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
if f == null:
    push_error("SaveGame: no se pudo escribir (%s)" % error_string(FileAccess.get_open_error()))
    return
f.store_string(JSON.stringify(d))
f.close()
if DirAccess.rename_absolute(PATH + ".tmp", PATH) != OK:
    push_error("SaveGame: no se pudo renombrar el temporal")
```

Also keep a `save.json.bak` and fall back to it in `load_game()` when the primary file fails to parse. Consider writing every N seconds rather than only at commit points (`level.gd:_save()` is called on menu close and floor change — a crash mid-run loses the whole run).

---

## 2. HIGH (should fix)

### H1 — "Nueva partida" can silently fail to delete the old save
**`scripts/title.gd:41`**

```gdscript
DirAccess.remove_absolute(SaveGame.PATH)
_start()
```

The return code is ignored. If the delete fails (file locked, permission), the player clicks "Nueva partida", the title screen advances, and `level.gd:_ready` → `SaveGame.load_game()` loads the **old run** — the player silently continues the previous character after being told everything was wiped.

Compounding it, the confirmation is implemented by mutating the button's text (line 39). The confirmation state is never reset, so if the player clicks "Nueva partida" once, wanders off, and clicks it again later, the save is deleted with no confirmation.

**Fix:** check the error code and abort the transition on failure; use a boolean `confirming` flag reset on focus change rather than comparing button text.

### H2 — Failing tests hang the run instead of failing it
**`tests/*.gd` (13 of 14 files)**

`assert()` in GDScript halts execution of the enclosing function on failure but does **not** set a non-zero exit code. In `tests/test_run.gd`, `test_meta.gd`, `test_pacts.gd`, `test_intents.gd`, etc., a failed assertion aborts `_init()` *before* the final `quit()` — the headless SceneTree then runs forever with no output. The CI exit code stays `0`.

`tests/test_flow.gd` already demonstrates the correct pattern (a local `fail()` helper that prints and calls `quit(1)`), and `test_inventory_relics.gd` uses `quit(0 if found else 1)`. The other 13 files should be converted to the same shape.

Related: **`.github/` contains only `CODE_REVIEW_REPORT.md` — there is no CI workflow**, so nothing runs these tests automatically. A test harness is worth adding.

### H3 — `_free_pos` can place enemies inside walls or on top of the player
**`scripts/level.gd:379-385`**

```gdscript
for i in 60:
    p = Vector2(randf_range(...), randf_range(...))
    if p.distance_to(avoid) >= min_dist and not blocked.any(...) and not event_spots.any(...):
        break
return p
```

If no candidate satisfies the constraints in 60 tries, the function returns the **last random candidate** — which may be inside a wall block or on the player's start position. The elite in particular is placed with `min_dist = 160` (`level.gd:511`), which is hard to satisfy in a 640×360 room, so this fallback is reachable in practice.

**Fix:** track whether a valid point was found and, if not, fall back to a known-safe anchor (e.g. the room center) rather than the last rejected sample. `test_floor_reachability.gd` does a flood-fill check, but only over `floor_obj` positions, so it would not catch an enemy spawned inside a wall.

### H4 — `null` dereferences on `ui` and `current_enemy` are only partially guarded
**`scripts/battle_system.gd:85, 94, 169, 218, 221, 238` and `scripts/level.gd:807, 833-843`**

`BattleSystem._ready` logs `"BattleSystem: UI no encontrada"` and leaves `ui` as `null` (`battle_system.gd:32-33`). Some call sites check (`start_battle` line 51, `player_attack` line 128), but many do not — `next_turn` calls `ui.float_text(...)` and `ui.update_stats()` unconditionally at lines 85-94, and `_use_skill` calls `ui.float_text` at line 221. A missing `$BattleUI` therefore produces a null-instance crash in the middle of a battle instead of the intended clean error.

Similarly, `level.gd:_on_battle_ended` dereferences `current_enemy` (lines 833-843) with no null check. `current_enemy` is only assigned inside `try_start_battle`; any battle started directly through `battle_system.start_battle` (as several tests do) leaves it `null` → "Invalid get index 'has_meta' on a null instance".

**Fix:** either fail fast in `_ready` (`assert(ui != null)` / `push_error` + `set_process(false)`) or guard every call site. Add `if current_enemy == null: return` at the top of `_on_battle_ended`.

### H5 — The "Ayuno" pact is exploitable outside combat
**`scripts/battle_system.gd:328` vs `scripts/inventory_menu.gd:66-69`**

Ayuno ("Sin objetos: ni usarlos ni llevarlos") is enforced only in the battle item menu. The field inventory menu still allows consuming potions freely:

```gdscript
func _on_item(item: ItemData):
    if item.type == ItemData.ItemType.CONSUMABLE:
        character.use_item(item)   # <- no pact check
```

Since Ayuno also grants an essence bonus (`Pacts.PACTS`), a player can take the pact, loot potions, and drink them in the field. **Fix:** check `character.pacts.has("ayuno")` in `InventoryMenu._on_item` and reject consumables the same way `BattleSystem._on_item_pressed` does.

---

## 3. MEDIUM (consider fixing)

### M1 — `ItemData.find_by_id` rebuilds the entire item catalogue on every call
**`scripts/item_data.gd:122-127`**

```gdscript
static func find_by_id(item_id: String) -> ItemData:
    for list in [get_all_weapons(), get_all_armors(), get_all_accessories(), get_all_consumables()]:
```

Each of the four getters allocates a fresh set of `ItemData` objects, so one lookup constructs **28 throwaway objects**. This is on the hot path: every shop purchase (`shop_menu.gd:81`), every save load (`save_game.gd:51-53`, once per item), every quest claim, and `generate_drops` on every battle victory (`battle_system.gd:369`).

**Fix:** build the catalogue once into a `static var _by_id: Dictionary` and return from it. This also fixes a subtle identity problem — `shop_menu._buy` adds `find_by_id(item.id)` (a *different* instance from the one in `stock()`), so `Inventory.has_item()` (reference comparison) would return `false` for it.

### M2 — `level.gd` is 879 lines with five distinct responsibilities
**`scripts/level.gd`**

Floor generation (`_build_walls`, `_spawn_floor`, `_free_pos`), combat orchestration (`try_start_battle`, `_on_battle_ended`), meta progression (`_gain_essence`, `_refresh_modifiers`), NPC dialogue (`_say`, `_talk`, `_claim`, `_rest`), and UI construction (`_show_class_select`, `_boss_intro`) all live in one file, with `_on_battle_ended` alone coordinating six subsystems.

**Fix:** extract at least `FloorBuilder` (generation + placement) and `RunFlow`/`MetaService` (essence, altar, run lifecycle). The `_choose`/`_open_dialog` pattern is already a good seam — the meta logic can move behind it.

### M3 — `battle_system.gd` claims multi-player support but hardcodes `player_team[0]` everywhere
**`scripts/battle_system.gd` (lines 120, 139, 160, 275, 299, 303, 307, 340-346) vs. the loops at lines 246, 265**

`player_team` is typed `Array[CharacterData]` and `check_battle_end` iterates it with `for p in player_team`, implying multiple party members — but every action path hardcodes index `0`. `damage_vs`, `single_target`, `incoming_damage` and all of `battle_ui` assume a single player.

**Fix:** either collapse to a single `player: CharacterData` field (honest about the design) or complete the multi-player support. The current state will mislead anyone extending it.

### M4 — Stale `nearby` interaction state with overlapping NPCs
**`scripts/level.gd:256-262`**

```gdscript
a.body_entered.connect(func(_b): nearby = on_enter; lbl.visible = true)
a.body_exited.connect(func(_b):
    if nearby == on_enter: nearby = Callable()
    lbl.visible = false)
```

With two NPCs in range, exiting one clears `nearby` (if it happened to be the active one) and hides that NPC's label while the other remains overlapped — leaving the player unable to interact with the NPC they are standing on. **Fix:** track a set of nearby interactables and resolve the active one by distance.

### M5 — `current_enemy` is not cleared when the floor is cleared
**`scripts/level.gd:282-286`**

`_clear_floor()` frees every `floor_obj` but leaves `current_enemy` pointing at a queued-for-deletion node. Any later access (`_on_battle_ended`, `_on_battle_fled` at line 878) touches a freed instance. It happens to be reassigned by `try_start_battle` before each fight, but the invariant is fragile. **Fix:** set `current_enemy = null` in `_clear_floor`.

### M6 — Enemy AI does an O(n) `Rect2.grow()` scan every physics frame
**`scripts/enemy_ai.gd:106-107`**

```gdscript
func _free(p: Vector2) -> bool:
    return level.enemy_bounds().has_point(p) and not level.blocked.any(func(r): return r.grow(8).has_point(p))
```

`level.blocked` holds ~45 `Rect2`s. This runs per enemy, per axis, per frame (2 axes × 60 fps × ~8 enemies × 45 rects ≈ **43k `Rect2.grow()` allocations per second**, each allocating a new `Rect2`). **Fix:** precompute the grown rects once per floor (e.g. store `blocked_grown` alongside `blocked`) and use `Rect2.has_point` on the precomputed values.

### M7 — `CharacterData.equip()` raises a `KeyError` on a consumable
**`scripts/character_data.gd:185-187`**

```gdscript
var slot = {ItemData.ItemType.WEAPON: "weapon", ...}[item.type]
```

`equip` is a public method with no type guard; passing a `CONSUMABLE` aborts with a dict-key error. Both call sites (`inventory_menu.gd:70`, `sim_balance.gd:144`) filter by type first, but the method itself should be defensive. **Fix:** return `null` (or `push_error`) for unsupported types.

### M8 — Unchecked array indexing on skill/target selection
**`scripts/battle_system.gd:140, 357` and `scripts/battle_ui.gd:278-279`**

`player_team[0].skills[skill_index]` and `enemy_team[target_index]` are indexed without bounds checks. `_on_skill_selected` passes `first_alive_enemy()`, which returns **`-1`** when no enemy is alive; GDScript treats a negative index as a wrap-around, so `enemy_team[-1]` silently targets the *last* enemy rather than erroring. Currently harmless (a heal skill ignores its target, and the battle would already have ended), but the failure mode is silent and wrong rather than loud. **Fix:** guard with an explicit bounds/emptiness check.

### M9 — `battle_ui._build_stage` frees sprites with `queue_free` but keeps using them for one frame
**`scripts/battle_ui.gd:156-175`**

Old sprites remain children (and visible) until the end of the frame while `sprites`/`hp_bars` dicts are cleared and repopulated. A `float_text` or `update_stats` in that window resolves against the *new* dict entries while the *old* sprites are still on screen. **Fix:** call `remove_child` + `queue_free` so the old nodes leave the tree immediately.

### M10 — `tools/make_ui.py` writes to a CWD-relative path, unlike its siblings
**`tools/make_ui.py:37`**

```python
f(st).save(f"assets/ui/btn_{name}_{st}.png")
```

`make_floor1.py` and `make_stairs.py` both resolve paths against `os.path.dirname(__file__)`. `make_ui.py` only works when run from the repo root, and otherwise silently writes the assets into the wrong directory. **Fix:** use the same `os.path.join(os.path.dirname(__file__), "..", "assets", "ui", ...)` pattern, and `os.makedirs(..., exist_ok=True)`.

---

## 4. MINOR (nice to have)

- **`scripts/level.gd:722-724`** — `_note()` creates a new `SceneTreeTimer` per message; messages accumulate. Consider reusing a single timer.
- **`scripts/player.gd:35-36`** — the WASD fallback uses `Input.is_key_pressed(KEY_D)`, which is layout-dependent (AZERTY/Dvorak players get the wrong keys). Prefer physical keycodes via `InputEventKey.physical_keycode`, or drop the fallback and rely on `ui_*` actions.
- **`scripts/battle_system.gd:212`** — `_power` truncates with `int(base * m)`, so a 15-damage hit under *Sed de Sangre* deals 22 rather than 22.5. Consistent, but worth a comment or `roundi`.
- **`scripts/dialogues.gd:59-70`** — `matches()` silently returns `false` for an unrecognised `when` key, so a typo in a dialogue condition makes that variant unreachable with no error. Add an `else: push_error(...)` branch.
- **`scripts/dialogues.gd` ↔ `scripts/level.gd:760`** — the dialogue `do` actions are resolved through a dict in `level.gd` (`acts = {"quest": ..., "rest": ..., "shop": ...}`); a new `do` value in `dialogues.gd` causes a `KeyError` at runtime rather than a compile-time error.
- **`scripts/meta.gd:29-30`** — `cost(u)` recomputes `u.cost * (level+1)`, but `Meta.UPGRADES` entries are untyped `Dictionary`s; `u.cost` and `u.id` are unvalidated. Consider a small typed structure.
- **`scripts/sfx.gd:11-17`** — `p.finished.connect(p.queue_free)` never fires if the stream is invalid, leaking the `AudioStreamPlayer`. Consider a fallback or a pool.
- **`scripts/music.gd:25-29`** — `play()` uses `call_deferred()` for both `add_child` and `play()`; two rapid calls with different keys can restart the same stream twice. Minor audio glitch.
- **`scripts/shop_menu.gd:90-100`** — `refresh()` uses `queue_free()` on the old sell buttons and immediately appends new ones, so duplicates are visible for one frame.
- **`scripts/level.gd:431`** — `_make_area(...).get_child(0).visible = false` hides the stairs sprite by reaching into the child hierarchy. Return the sprite or add a parameter instead.
- **`tests/sim_balance.gd:143-147`** — the simulator equips items without removing them from the inventory (the real game does remove them, `inventory_menu.gd:73`), so the simulation overstates inventory pressure. Also `sim_balance.gd:173` — `meta.streak = 0 if ok else meta.streak` is dead code (`ok` is always `true` there).
- **`tools/make_floor1.py:9`** — a missing `~/Downloads/nivel1` surfaces as a bare `FileNotFoundError`; a friendly message with the resolved path would help.

---

## What the code does well

Worth preserving in any refactor:

- **Intent telegraphing is honest** — `battle_system.gd:185-206` computes exactly what the enemy will do, and `tests/test_intents.gd` asserts the previewed damage equals the applied damage. This is the kind of thing that is easy to break silently; it is well covered.
- **`CharacterData.preview_damage` / `take_damage` share the same code path** (`character_data.gd:176-183`), so the UI can never disagree with the simulation about a hit.
- **`Pacts.scale_enemy` is pure** and its scaling matrix is verified branch-by-branch in `tests/test_pacts.gd`.
- **The test suite is unusually good for a game project** — `test_floor_reachability.gd` does a real flood-fill over procedurally generated floors, and `test_shop.gd` checks the gold arithmetic exactly. The infrastructure is sound; it only needs the `assert` → `fail()` conversion from H2 and a CI workflow.
- **Save/load round-trips are tested** for both the run-state and the meta-only case (`test_run.gd:50-58`, `test_meta.gd:47-54`).

---

### Suggested order of work
1. **C1** — atomic save with backup (data loss).
2. **H1, H2** — save deletion error handling and test exit codes (both are silent-failure classes).
3. **H3, H4, H5** — the three gameplay correctness bugs.
4. **M1, M6** — the two measurable performance problems.
5. **M2, M3** — structural cleanups, best done on their own branch.