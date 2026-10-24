# Code Review Report: VampireCityRPG
Generated: 2026-10-25T00:29:55.161957

I have a complete picture of the codebase now. Here is the review.

---

# Code Review — VampireCityRPG

**Scope:** `scripts/` (28 files), `tests/` (14 files), `tools/` (3 Python scripts) — ~4,500 lines. Assets/binary files excluded.

**Overall:** This is clean, well-organized code for a game of this size. The architecture is coherent (data objects → systems → UI), asset paths all resolve, there is no `eval`, no network I/O, no shell-out, no untrusted input, and no credential handling — **there are no security vulnerabilities**. The defects below are correctness and maintainability issues, not exploits.

---

## 1. CRITICAL (must fix)

### C1 — Save file can be truncated with no recovery, losing the meta-progress permanently
`scripts/save_game.gd:19-20`

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

Two problems:
- `FileAccess.open` returns **null** on failure (read-only `user://`, disk full, permissions). `f.store_string` on null is a hard runtime error, and the crash happens *during* `JSON.stringify` evaluation's consumer — the file is already truncated to zero length at that point.
- The write is **not atomic**. If the process is killed mid-`store_string`, `save.json` is a partial JSON string. `load_game()` then hits `typeof(d) != TYPE_DICTIONARY` and returns `[]` — and `level.gd:59` treats that as "no run", which means `meta` (essence, altar levels) and `quests` are gone too, with no way to recover.

**Fix:**
```gdscript
var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
if f == null:
    push_error("SaveGame: no se pudo escribir el guardado (%s)" % error_string(FileAccess.get_open_error()))
    return
f.store_string(JSON.stringify(d))
f.close()
var da := DirAccess.open("user://")
if da.rename(PATH + ".tmp", PATH) != OK:
    push_error("SaveGame: no se pudo renombrar el guardado temporal")
```

---

## 2. HIGH (should fix)

### H1 — `busy` is a single global modal flag with no owner tracking; a missed `closed` signal softlocks the game
`scripts/level.gd:103, 170, 182, 675, 689, 744` (set) and `:140, 175, 188, 681, 694, 751` (reset)

`busy` is set to `true` in seven places and reset only in the corresponding `closed`/`resumed` signal callbacks. If any of those menus is freed without emitting its signal (scene reload during `_end_run` → `get_tree().reload_current_scene()` at `level.gd:865` while a menu is open; or a node freed by `_clear_floor`), `busy` stays `true` forever, and because `level.gd:156` returns early on `busy`, **the player can no longer interact, open the inventory, or pause — a permanent softlock with no way out except restarting.**

**Fix:** use a counter instead of a bool, or set `busy = false` in `_exit_tree()` of the level and in a `NOTIFICATION_WM_CLOSE_REQUEST`/`_notification(NOTIFICATION_PREDELETE)` hook. A minimal robust change:
```gdscript
# en level.gd
func _exit_tree() -> void:
    busy = false
```
plus, in `_end_run`, `busy = false` before `reload_current_scene()`.

### H2 — `_note()`'s timer callback touches a freed node after every scene transition
`scripts/level.gd:720-724`

```gdscript
msg.text = text
get_tree().create_timer(3.0).timeout.connect(func():
    if msg.text == text:
        msg.text = "")
```

The `SceneTreeTimer` is owned by the tree, not by the level. The lambda captures `self` and `msg`. If the level is freed within those 3 seconds — which happens on **every death** (`_end_run` → `reload_current_scene()`) and on **every "Menú principal"** (`pause_menu` → `change_scene_to_file`) — the timer fires on a freed `Node` and raises *"Attempt to call function on a previously freed instance"*. Notes are emitted constantly (every essence gain, every floor, every pickup), so this fires reliably.

**Fix:** disconnect the timer on exit, or guard:
```gdscript
get_tree().create_timer(3.0).timeout.connect(func():
    if is_instance_valid(self) and is_instance_valid(msg) and msg.text == text:
        msg.text = "")
```

### H3 — `current_enemy` is dereferenced without a null check on the battle-end path
`scripts/level.gd:833, 835, 837, 840-841, 878`

`_on_battle_ended` uses `current_enemy.has_meta("boss")` and `current_enemy.position`; `_on_battle_fled` uses `current_enemy.position`. `current_enemy` is only ever assigned in `try_start_battle` (`level.gd:800`), and is never cleared. It is `null` before the first battle and after a scene reload, so any battle lifecycle path that fires `battle_ended` without going through `try_start_battle` (e.g. `battle_system.start_battle` called directly, as `tests/test_flow.gd:92` does) crashes with a null-instance error.

**Fix:** `if current_enemy == null or not is_instance_valid(current_enemy): return` at the top of `_on_battle_ended` and `_on_battle_fled`.

### H4 — Enemy collision avoidance runs an O(n) scan per axis per frame, per enemy
`scripts/enemy_ai.gd:106-107`

```gdscript
func _free(p: Vector2) -> bool:
    return level.enemy_bounds().has_point(p) and not level.blocked.any(func(r): return r.grow(8).has_point(p))
```

`blocked` holds up to ~45 rects (`level.gd:329`). `_step` calls `_free` twice per axis per enemy, and there are up to 8 enemies at 60 Hz → ~43,000 `Rect2.grow().has_point()` allocations + calls per second. `grow(8)` allocates a new `Rect2` on every invocation.

**Fix:** precompute a grown list once per floor (`blocked_grown`) in `_spawn_floor`, or better, build a coarse grid (e.g. 16 px cells) mapping to blocked flags and look up in O(1).

### H5 — `save_game.gd` silently accepts unknown equipment slots from the file
`scripts/save_game.gd:50-51`

```gdscript
for slot in d.get("equipment", {}):
    c.equipment[slot] = ItemData.find_by_id(d.equipment[slot])
```

The loop iterates the *file's* keys, not the known slots. A hand-edited or partially-written save containing `"helmet": "x"` inserts a bogus key into `c.equipment`. `CharacterData.equip()` (`character_data.gd:186-194`) then looks up slots by name, so it is not directly exploitable, but `save_game.gd:18` iterates `c.equipment` and writes it back out — the bogus key **persists across save/load cycles**.

**Fix:** iterate the known slots and ignore unknown ones:
```gdscript
for slot in ["weapon", "armor", "accessory"]:
    var id = d.get("equipment", {}).get(slot, "")
    if id != "":
        c.equipment[slot] = ItemData.find_by_id(id)
```

---

## 3. MEDIUM (consider fixing)

### M1 — Menu rebuilds use `queue_free()` and immediately re-add children to the same parent
`scripts/battle_ui.gd:139-140, 307-309`, `scripts/shop_menu.gd:92-93`, `scripts/inventory_menu.gd:44-45`, `scripts/altar_menu.gd:49-53`

`queue_free()` defers removal to the end of the frame, so for one frame the parent contains both the old and the new children. In `battle_ui._show_list` this means duplicate skill buttons are laid out and the old button may still hold focus when the new one is created. `battle_ui.update_stats` (`:254`, `:262`) clears and refills the status/intent rows every time — this flicker happens on *every* turn.

**Fix:** use `remove_child(n); n.queue_free()` for the immediate detach, or reuse the existing buttons instead of recreating them.

### M2 — `battle_ui._apply_button_style` replaces the project theme, losing the Jersey 10 font
`scripts/battle_ui.gd:71-85`

Assigning `theme = th` (a fresh `Theme` with only styleboxes) to `BattleUI` makes that subtree use `th`. Since `th.default_font` is null, the battle buttons fall back to the engine default font instead of the project-wide `Jersey10` set in `assets/theme.tres:50`. The result is a visible font inconsistency between the battle panel and every other menu.

**Fix:** copy the font over — `th.default_font = ThemeDB.get_default_theme().default_font` won't help; instead set `th.default_font = load("res://assets/fonts/Jersey10.ttf")` or apply the styleboxes to a duplicated project theme: `var th = get_theme().duplicate()`.

### M3 — `battle_system` dereferences `ui` even though `_ready` tolerates it being missing
`scripts/battle_system.gd:27-33, 51-56, 85, 94, 126, 143, 218, 231, 250`

`_ready` does `push_error("BattleSystem: UI no encontrada")` and continues; `start_battle` does the same and continues into `next_turn()`. The very next line in `next_turn` is `ui.update_stats()` → null-instance crash. The error path exists but is not actually handled.

**Fix:** `if ui == null: is_battle_active = false; return` in `start_battle`.

### M4 — `next_turn()` divides by `turn_order.size()` without guarding against an empty order
`scripts/battle_system.gd:71`

```gdscript
current_turn_index = (current_turn_index + 1) % turn_order.size()
```

`turn_order` is only populated by `calculate_turn_order()`, which is called once in `start_battle`. If `start_battle` is ever called with empty teams (or a team is cleared on death), this is a division-by-zero crash.

**Fix:** `if turn_order.is_empty(): return` at the top of `next_turn`.

### M5 — `player_use_skill` accepts an invalid target index; `-1` silently wraps to the last enemy
`scripts/battle_system.gd:135-147`

`first_alive_enemy()` returns `-1` when no enemy is alive (`battle_system.gd:110-114`). `_on_skill_selected` (`:352-357`) passes that straight into `player_use_skill` → `enemy_team[-1]`. In GDScript, `-1` is a *valid* index (the last element), so no crash occurs — but the skill is resolved against a dead enemy and the MP is still spent. The same applies to `player_attack(target_index)` at `:121`.

**Fix:** validate the index in both entry points:
```gdscript
if target_index < 0 or target_index >= enemy_team.size(): return
```

### M6 — Level reaches into `battle_system`'s internals instead of using an API
`scripts/level.gd:625` (`battle_system.gold_mult`), `:807` (`battle_system.ui.set_backdrop`), `:825` (`battle_system.ui.visible = false`), `:833` (`battle_system.enemy_team.size()`)

The level reaches into the battle system's public fields and its UI child directly. This couples the two nodes tightly and means `battle_system.ui` is dereferenced without a null check (see M3).

**Fix:** add narrow methods on `BattleSystem` — `set_gold_mult()`, `set_backdrop()`, `hide_ui()`, `enemy_count()`.

### M7 — `_free_pos` can return a position inside a wall
`scripts/level.gd:379-385`

If none of the 60 attempts satisfies the constraints, the loop exits with the last random point, which may be inside a `blocked` rect, on top of the player, or off the intended area. Enemies spawned there can be unreachable (the `test_floor_reachability.gd` flood-fill check covers `blocked` but not this fallback).

**Fix:** keep the last *valid* candidate and fall back to `area.get_center()` only if none was ever valid; log a warning.

### M8 — Quest counters are global and never reset per quest
`scripts/quest_log.gd:19-20`, `scripts/level.gd:771, 832`

`counters["kill"]` accumulates across every quest. The first quest needs 5 kills; the second needs 20 — but the counter already reads 5 when the second quest becomes current, so it is 15 kills easier than intended. The same applies to the `boss` quests (1 → 3 → 6).

**Fix:** store the counter value at claim time and subtract it when the next quest becomes current, or key counters by quest id.

### M9 — `level_offers` can offer a skill the character already knows twice
`scripts/upgrades.gd:24-32`

The filter uses `sk.name in known` (a name comparison) while `CharacterData.sync_skills` (`character_data.gd:137`) selects by `unlock_level`. If two distinct skills in a class ever share a name, the level offer will hand out a duplicate. More practically, `Upgrades.apply` (`:40-46`) appends the *same* `SkillData` object that `CharacterData.class_skills` returned — and `class_skills` constructs **new** objects on every call, so the object identity in `c.skills` differs from the one in a later `class_skills()` result. `save_game.gd:43` reconstructs skills by name, which works, but any code comparing skill objects by identity would break.

**Fix:** give `SkillData` a stable `id` and match on that.

---

## 4. MINOR (nice to have)

### m1 — Dead code
`scripts/character_data.gd:161` `status_text()`, `scripts/player.gd:93` `get_input_direction()`, `scripts/inventory.gd:23, 29, 32, 35` (`has_item`, `get_weapons`, `get_armors`, `get_accessories`), `scripts/inventory.gd:3` `inventory_updated` signal — none are referenced anywhere in `scripts/` or `tests/`. `Inventory.get_weapons/get_armors/get_accessories` duplicate `ItemData.get_all_*` filtering.

### m2 — `Controls.setup()` hooks `node_added` on the root and never disconnects it
`scripts/controls.gd:8-12`

`tree.node_added.connect(...)` is guarded by the static `_click_hooked`, so it only ever fires once per process — but the connection is never removed, so in a test harness that creates multiple `SceneTree`s, later trees never get the click sound. The lambda also calls `Sfx.play(tree.root, ...)`, which adds a child to `root` from inside a `node_added` callback — re-entrant on `root` if the button being added is a direct child of `root`.

**Fix:** use `call_deferred` for the `add_child`, and reset `_click_hooked = false` when the tree changes.

### m3 — `add_status` cannot shorten an existing status
`scripts/character_data.gd:145-146` — `statuses[s] = maxi(turns, statuses.get(s, 0))`. Applying a 1-turn status to one with 3 turns leaves 3. Intentional for stacking buffs, but it means a debuff can never be shortened by a weaker application.

### m4 — `Inventory.remove_item` relies on reference identity
`scripts/inventory.gd:15-21` — `items.find(item)` compares `ItemData` objects by reference. It happens to work because `ItemData.find_by_id` returns fresh instances and every call site keeps the instance it inserted, but any future refactor that re-resolves items by id will silently fail to remove. A `remove_item_by_id` or an explicit `id` comparison would be more robust.

### m5 — `tools/make_floor1.py` has an O(n²) pure-Python flood fill and dilation
`tools/make_floor1.py:44-67` — `components()` does a nested Python loop over every pixel for both the dilation (`grow`×`grow` shifted ORs) and the connected-component search. For large source JPEGs this takes minutes.

**Fix:** use `scipy.ndimage.label` / `binary_dilation`, or vectorize the dilation with `numpy.lib.stride_tricks.sliding_window_view`.

### m6 — Unused loop variables
`scripts/level.gd:343` (`for i in 3:`), `:349` (`for i in 40:`), `:370` (`for i in 10:`), `:595` (`for i in 2:`), `scripts/character_data.gd:252` (`for i in enemy_team.size():`) — GDScript emits an "unused variable" warning for each. Prefix with `_` to silence.

### m7 — `_show_class_select` closures capture the loop variable
`scripts/level.gd:118-147` — `var data = CharacterData.create_for_class(c)` is declared *inside* the loop, so each iteration's closure captures its own instance. This is correct in GDScript, but it is fragile-looking enough that a future refactor moving `data` outside the loop would silently break class selection. Worth a comment.

### m8 — `Music.play` defers both `add_child` and `play`
`scripts/music.gd:25-29` — `add_child.call_deferred()` followed by `play.call_deferred()`: the two deferred calls are queued in order, but between them the frame boundary can land, producing a one-frame of silence on every track change. Consider `await get_tree().process_frame` after the deferred `add_child`, or simply adding the player to the tree in `_init` of a dedicated autoload.

---

## What is genuinely good

Worth saying explicitly, because it is unusual:

- **No security exposure.** No network calls, no `OS.execute`, no `eval`, no deserialization of untrusted data, no secrets. The only file I/O is `user://save.json` via `JSON`, and the only external input is keyboard/gamepad.
- **Asset paths all resolve.** I verified every `load()` target in `scripts/` against the filesystem: all `tile_*.png`, `assets/ui/btn_{a,b,c}_*.png`, `assets/sprites/floor1/*`, `assets/sprites/{classes,enemies,npcs}/*`, `assets/audio/*`, `assets/audio/music/*`, and `assets/backgrounds/*` exist. The `BACKDROPS`/`FLOORS` index arithmetic is consistent with the assets on disk.
- **Good test coverage.** 14 headless test scripts, 130 assertions, covering flow, save/load round-trip, intents-vs-actual-damage, targeting, reachability (flood fill), NPC collision, pacts, meta economy, and content completeness. `test_floor_reachability.gd` generating 60 random floors and flood-filling them is a strong regression net.
- **Intent/damage parity.** `intent_info()` and the actual attack both route through `preview_damage()`/`_power()`, so the displayed number cannot drift from the applied number — and `test_intents.gd` asserts exactly that.
- **Encapsulation of the damage formula.** `preview_damage`/`take_damage` centralise defense, the `debil` status, and the floor of 1 damage.

---

## Suggested order of work

1. **C1** (atomic save) — the only issue with permanent, unrecoverable player-data loss.
2. **H1 + H2** (softlock + freed-node timer) — both are reachable in normal play (dying, returning to title) and are cheap to fix.
3. **H3, M3, M4, M5** — null/index guards; a few lines each.
4. **M1, M2** — visible flicker and the font inconsistency; user-facing polish.
5. **M8** (quest counters) — a balance question, so it may need a design decision rather than a mechanical fix.

Note that I could not execute the test suite: no `godot` binary is available in this environment (`godot`/`godot4` are not on `PATH` and no Godot app is installed), so all findings above are from static reading, not from running the game or the tests.