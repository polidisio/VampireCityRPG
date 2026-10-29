# Code Review Report: VampireCityRPG
Generated: 2026-10-30T00:31:13.319946

I verified the `class_name` declarations directly — `controls.gd:1` is `class_name Controls`, so my earlier suspicion there was wrong. Dropping that item. I also re-verified the backdrop paths (`BACKDROPS = [5,6,6,5,6]` are per-theme *counts* for themes 0–4, and all 27 files exist) — also not a bug. And I traced the equipment save path carefully: `load_game` restores `attack`/`defense` as absolute values and assigns `c.equipment[slot]` directly without calling `equip()`, so there is no double-counting. That item is also dropped.

Here is the corrected, final report.

---

# Code Review — VampireCityRPG

**Scope:** all 27 files in `scripts/`, 12 in `tests/`, 3 in `tools/`. Scene files and asset paths cross-checked to validate assumptions.

The codebase is clean, idiomatic Godot 4, and unusually consistent. No injection, auth, or secret exposure — it's an offline game with a single local `user://save.json`. The real risks are in **save integrity** and **state coordination between the map and the battle system**.

---

## 1. CRITICAL

### C1 — The previous floor's interaction areas stay live for a physics frame, binding the wrong action to E
`scripts/level.gd:282-286` (`_clear_floor`), `scripts/level.gd:288-306` (`_go_floor`), `scripts/level.gd:256-262`

```gdscript
func _clear_floor():
    nearby = Callable()
    msg.text = ""
    for n in get_tree().get_nodes_in_group("floor_obj"):
        n.queue_free()          # deferred!
```

`_go_floor` calls `_clear_floor()` (line 290), then `_spawn_floor()`, which teleports the player to `start_pos` (line 411), then awaits `get_tree().physics_frame` twice (lines 304-305).

`queue_free()` defers deletion to the end of the idle frame (`SceneTree::flush_delete_queue`). Because the coroutine resumes on **`physics_frame`**, the next physics step runs *before* that flush — so the old floor's `Area2D` nodes are still in the tree when the physics server re-checks overlaps for the player's new position.

The hub makes this concretely wrong. The hub altar is placed at `Vector2(48, 160)` with `size = 24` (`level.gd:430`), and `_make_area` gives hinted NPCs a collision box of `size + 22 = 46` px (`level.gd:239`). Descending into the tower puts the player at `start_pos = Vector2(48, 180)` (`level.gd:404`). Player box (8×8) is y∈[176,184]; the altar's box is y∈[137,183]. **They overlap.** The stale altar area fires `body_entered`, which sets `nearby = _open_altar` and makes its "E: Altar" label visible — on the tower floor, at the hub's coordinates. Pressing E then opens the meta-progression Altar menu mid-run.

Note that `_clear_floor` explicitly resets `nearby = Callable()` (line 283) — the stale area immediately re-sets it, which is what makes the intent of that line ineffective.

**Fix:** detach from the tree before freeing, so the node stops participating in the physics server immediately:
```gdscript
func _clear_floor():
    nearby = Callable()
    msg.text = ""
    for n in get_tree().get_nodes_in_group("floor_obj"):
        n.get_parent().remove_child(n)   # deja de detectar areas de inmediato
        n.queue_free()
```
This is robust regardless of the physics/idle ordering.

---

### C2 — A failed or interrupted save leaves a corrupt file that crashes the game on next launch
`scripts/save_game.gd:19-20`, `scripts/save_game.gd:26-56`

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

Two problems. `FileAccess.open` returns **null** on failure (read-only dir, permission error, disk full) — `f.store_string` on null is a null-instance error, and the failure is invisible to the caller. And the file is never explicitly closed, so the write is flushed at an indeterminate point relative to process exit.

`load_game()` then trusts the file. Only `typeof(d) == TYPE_DICTIONARY` and `d.has("gold")` are validated (`save_game.gd:27`), but everything downstream is assumed well-formed:

| Line | Assumption | Failure on malformed input |
|---|---|---|
| `save_game.gd:43` | `d.skills` is an Array of Strings | If it's a String, `sk.name in d.skills` is a **substring** test → silently wrong skill set. If a Dictionary → key test. No error. |
| `save_game.gd:46` | `d.relics` is an Array | `.has()` on a non-Array → runtime error |
| `save_game.gd:49` | `d.pacts` is an Array | same |
| `save_game.gd:50-51` | `d.equipment` is a Dict of String→String | `ItemData.find_by_id(d.equipment[slot])` — `find_by_id` is typed `item_id: String`; a number or nested object is a **type error**. A non-Dict `equipment` iterates wrongly. |
| `save_game.gd:52-55` | `d.items` is an Array of Strings | `find_by_id(id)` — non-String → type error |
| `meta.gd:69` | `d.last_pacts` is an Array | later `.has()` → error |
| `meta.gd:71` | `d.levels` is a Dict | `d.levels[k]` on a list → error |
| `quest_log.gd:39` | `d.claimed` is an Array | later `.has()` → error |

Two are silent-corruption rather than crashes, which is worse: a `skills` value of `"Golpe Brutal"` would restore a *substring* match — e.g. a skill named `"Golpe"` would match `"Golpe Brutal"`.

**Fix:** write atomically and validate types at the boundary.
```gdscript
static func save(c: CharacterData, inv: Inventory, ...) -> void:
    ...
    var tmp := PATH + ".tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_error("SaveGame: no se pudo escribir " + tmp)
        return
    f.store_string(JSON.stringify(d))
    f.close()
    DirAccess.rename_absolute(tmp, PATH)   # atómico: nunca un save.json truncado
```
```gdscript
static func _arr(v: Variant) -> Array:
    return v if v is Array else []
static func _dict(v: Variant) -> Dictionary:
    return v if v is Dictionary else {}
```
Apply these to `d.get("skills")`, `d.get("relics")`, `d.get("pacts")`, `d.get("items")`, `d.get("equipment")`, `d.get("levels")`, `d.get("claimed")`, `d.get("last_pacts")`, and filter `items`/`skills` entries to Strings before use.

---

## 2. HIGH

### H1 — `Meta.from_dict` lets a corrupted save grant unlimited upgrade levels
`scripts/meta.gd:65-72`, `scripts/meta.gd:49-60`

```gdscript
for k in d.get("levels", {}):
    m.levels[k] = int(d.levels[k])
```

No upper bound. A save containing `{"levels": {"vida": 99}}` yields level 99 of an upgrade capped at 5. `Meta.buy` checks `level(u.id) < u.max` (`meta.gd:33`) so nothing more can be *bought*, but `apply_to_run` grants the stat bonus `level(u.id)` times (`meta.gd:52`):

```gdscript
Upgrades.add_stats(c, u.stats, level(u.id))
```

99 × "+10 max_hp" = **+990 HP**. Same for `fuerza` (+198 attack), `guardia`, `mente`. This is a direct save-tamper → balance break, and it also fires on an accidentally corrupted file.

**Fix:** clamp on load against the `max` declared in `UPGRADES`:
```gdscript
static func from_dict(d: Dictionary) -> Meta:
    var m := Meta.new()
    m.essence = maxi(0, int(d.get("essence", 0)))
    m.streak = maxi(0, int(d.get("streak", 0)))
    m.last_pacts = d.get("last_pacts", []) if d.get("last_pacts") is Array else []
    var levels := d.get("levels", {}) if d.get("levels") is Dictionary else {}
    for u in UPGRADES:
        m.levels[u.id] = clampi(int(levels.get(u.id, 0)), 0, u.max)
    return m
```
This also drops unknown ids, so a stray key can't inflate anything.

### H2 — `try_start_battle` is not idempotent and the stairs handler bypasses the `busy` guard
`scripts/level.gd:797-819`, `scripts/level.gd:870`, `scripts/level.gd:288-306`

`_unhandled_input` checks `busy` before calling `_go_floor` (`level.gd:163-165`), but the stairs `Area2D` handler calls it directly with no guard:

```gdscript
var stairs = _make_area(45, 16, _free_pos(near, player.position, 32.0), func(_a): _go_floor(floor_num + 1))
```

`_go_floor` sets `busy = true` (line 299) and then `await`s two physics frames (304-305) before clearing it (306). During that window the stairs area is still live. If the player is still overlapping the stairs when the handler fires again, `_go_floor` runs a **second** time: `_clear_floor()` frees the objects created by the first call, `_spawn_floor()` runs again, and `floor_num = n` is assigned again — with `floor_num` already incremented by the first call, so **a floor gets skipped**.

The same double-entry is possible on the hub stairs (`level.gd:431`).

**Fix:** guard `_go_floor` itself, and disable the stairs once used:
```gdscript
func _go_floor(n: int):
    if busy:
        return
    busy = true
    ...
```
and make the stairs handler consume itself:
```gdscript
func(_a):
    if busy: return
    _go_floor(floor_num + 1)
```

### H3 — The ambush coffin can be re-triggered indefinitely by fleeing
`scripts/level.gd:618-624`, `scripts/level.gd:264`, `scripts/level.gd:874-879`

```gdscript
func _open_coffin(node: Area2D, roll := randf()) -> void:
    if roll < 0.3: # emboscada
        node.set_meta("enemies", _enemy_group())
        nearby = Callable()
        _note("¡Emboscada!")
        try_start_battle(node)
        return          # el nodo sigue en el piso
```

The coffin is **not** removed on the ambush path — it becomes a permanent enemy. If the player flees (`_on_battle_fled`), the node and its `body_entered` connection survive. `_on_battle_fled` pushes the player only 24 px away (`level.gd:878`) while the coffin's interaction area is ~17 px wide (`size * 0.7` for a 24 px size → 16.8), so the player may still be inside and can step out and back in to **re-roll the ambush indefinitely**, farming the encounter.

**Fix:** mark the node consumed so it can't re-trigger:
```gdscript
if roll < 0.3:
    node.set_meta("enemies", _enemy_group())
    node.set_meta("used", true)
    nearby = Callable()
    _note("¡Emboscada!")
    try_start_battle(node)
    return
```
and in `_make_area`:
```gdscript
a.body_entered.connect(func(_b):
    if not busy and not a.has_meta("used"):
        on_enter.call(a))
```

### H4 — `current_enemy` is left pointing at a freed node
`scripts/level.gd:22`, `scripts/level.gd:612-616`, `scripts/level.gd:874-879`

`_remove_obj` frees the node but never clears `current_enemy`:
```gdscript
func _remove_obj(n: Node) -> void:
    if n.has_meta("solid") and is_instance_valid(n.get_meta("solid")):
        n.get_meta("solid").queue_free()
    n.queue_free()
    nearby = Callable()
```

After a victory, `current_enemy` references a queued-for-deletion `Area2D`. `_on_battle_fled` then does `current_enemy.position` (line 878) — a null-instance access if the node was freed in between (e.g. the player flees a battle whose enemy was removed by another path, or the scene reloads during `_end_run`).

**Fix:** clear it in `_remove_obj` and guard the read:
```gdscript
if current_enemy == n:
    current_enemy = null
```
```gdscript
func _on_battle_fled():
    _end_battle()
    chase_grace_until = Time.get_ticks_msec() + 3000
    if is_instance_valid(current_enemy):
        var away := (player.position - current_enemy.position)
        if away.length() > 0.001:
            player.move_and_collide(away.normalized() * 24)
    _save()
```

### H5 — `CharacterData.equip()` will crash if handed a consumable
`scripts/character_data.gd:185-194`

```gdscript
var slot = {ItemData.ItemType.WEAPON: "weapon", ...}[item.type]
var old: ItemData = equipment[slot]
```

The dictionary lookup returns `null` for `CONSUMABLE`, and `equipment[null]` is an invalid index → runtime error. Both current call sites guard the type (`inventory_menu.gd:67`, `sim_balance.gd:144-147`), so this is latent rather than live — but `equip()` is public API on a data class with no validation.

**Fix:** reject invalid types explicitly:
```gdscript
func equip(item: ItemData) -> ItemData:
    var slot: String = {ItemData.ItemType.WEAPON: "weapon", ItemData.ItemType.ARMOR: "armor", ItemData.ItemType.ACCESSORY: "accessory"}.get(item.type, "")
    if slot == "":
        return null
    ...
```

---

## 3. MEDIUM

### M1 — `ItemData.find_by_id` rebuilds every item list on every iteration
`scripts/item_data.gd:81-127`

```gdscript
static func find_by_id(item_id: String) -> ItemData:
    for list in [get_all_weapons(), get_all_armors(), get_all_accessories(), get_all_consumables()]:
        for i in list:
            if i.id == item_id:
                return i
    return null
```

The outer list is rebuilt on **every** iteration of the `for list in [...]` loop, and each `get_all_*()` constructs fresh `ItemData` objects. One `find_by_id` call allocates the four lists four times over — 4×(7+6+4+8) = 100 `ItemData` allocations. It's called per item on save/load (`save_game.gd:53`), per purchase (`shop_menu.gd:81`), and inside `get_all_consumables()` filters on every drop roll (`battle_system.gd:369`).

**Fix:** cache the catalogue once.
```gdscript
static var _catalog: Dictionary = {}

static func _cached(key: String, builder: Callable) -> Array[ItemData]:
    if not _catalog.has(key):
        _catalog[key] = builder.call()
    return _catalog[key]

static func find_by_id(item_id: String) -> ItemData:
    for key in ["weapons", "armors", "accessories", "consumables"]:
        for i in _cached(key, func(): return get_all_weapons()):  # o similar
            ...
```
Simplest version: build the four lists into `static var`s on first use and iterate those.

### M2 — Inventory identity is by object reference, so `remove_item` can silently fail
`scripts/inventory.gd:15-24`

```gdscript
func remove_item(item: ItemData) -> bool:
    var idx = items.find(item)      # identidad de referencia
func has_item(item: ItemData) -> bool:
    return items.has(item)          # también identidad
```

Because `get_all_*()` returns **new instances** each call, two `ItemData` objects with the same `id` are different objects. `shop_menu.gd:79-81` already works around this — it buys `ItemData.find_by_id(item.id)` rather than the button's instance. But any future call site that passes a freshly-constructed item to `remove_item` gets `false` back and no removal, with no error. `Inventory.has_item` is currently unused — dead code with a trap in it.

**Fix:** compare by `id`, which is the actual identity of an item:
```gdscript
func remove_item(item: ItemData) -> bool:
    for i in items.size():
        if items[i].id == item.id:
            items.remove_at(i)
            inventory_updated.emit()
            return true
    return false

func has_item(item: ItemData) -> bool:
    return items.any(func(i): return i.id == item.id)
```

### M3 — `_free_pos` can return a position inside a wall or on top of the player
`scripts/level.gd:379-385`

```gdscript
func _free_pos(area: Rect2, avoid: Vector2 = start_pos, min_dist: float = 100.0) -> Vector2:
    var p = area.get_center()
    for i in 60:
        p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
        if p.distance_to(avoid) >= min_dist and not blocked.any(...) and not event_spots.any(...):
            break
    return p
```

If all 60 attempts fail, the function returns the **last random sample** — which may be inside a wall block, inside the seal, or on top of the player. An enemy spawned inside a wall is permanently stuck (`EnemyAI._free()` rejects any position inside a `blocked` rect, `enemy_ai.gd:107`), and an event spawned on the player fires its handler immediately.

**Fix:** return a known-safe fallback rather than an arbitrary point:
```gdscript
    return area.get_center()   # el centro del área es transitable por construcción
```
The center of `_roam_rect()` is guaranteed inside the walkable region and outside `blocked` by the margins in `_placeable` (`level.gd:333`).

### M4 — `EnemyAI` holds untyped references to `Level`, defeating static checking
`scripts/enemy_ai.gd:10-11`, `scripts/enemy_ai.gd:44-51`

```gdscript
var area: Area2D
var level: Node
...
if level.busy or level.player.process_mode == Node.PROCESS_MODE_DISABLED:
```

`level.gd` has no `class_name` (it's `extends Node2D` only), so `level` can't be typed as `Level`. Every `level.busy`, `level.player`, `level.blocked`, `level.enemy_bounds()` access is a dynamic runtime lookup — renaming a property breaks it silently, and `level.blocked.any(func(r): return r.grow(8)...)` has no type information on `r`.

**Fix:** add `class_name Level` to `scripts/level.gd:1` and type it:
```gdscript
var level: Level
```
This enables static checking across `enemy_ai.gd`, `battle_system.gd`, and `player.gd`, and makes the `level.gd` ↔ `enemy_ai.gd` contract explicit.

### M5 — `_battle_backdrop` re-loads a texture on every battle`scripts/level.gd:388-391`

```gdscript
return load("res://assets/backgrounds/%d_%d.png" % [theme, randi() % BACKDROPS[theme]])
```

`load()` hits Godot's resource cache, so the cost is a dictionary lookup plus a `ResourceLoader` path parse — small, but it runs on every battle start and the result is thrown away immediately. The27 background files are all valid `compress/mode=0` PNGs.

**Fix:** cache the resolved textures in a `static var` dictionary, or preload them into a `const` array.

### M6 — `ShopMenu._buy` reports nothing when the backpack is full
`scripts/shop_menu.gd:76-82`

```gdscript
func _buy(item: ItemData):
    if item.type == ItemData.ItemType.CONSUMABLE and inventory.get_consumables().size() >= inventory.max_consumables:
        return # mochila llena (se ve en la cabecera)
```

The player presses the button, gold is not spent, and nothing happens — no sound, no log, no tooltip change. The header does show `Mochila N/M`, but only after a `refresh()` that never happens. The comment assumes the player will notice, which is a stretch.

**Fix:** give feedback — `Sfx.play(self, "click")` plus a one-line note in the gold label, or disable the button when the backpack is full.

### M7 — `Player._physics_process` reads raw key state alongside the InputMap actions
`scripts/player.gd:30-37`

```gdscript
var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
# WASD fallback
if input_direction == Vector2.ZERO:
    input_direction = Vector2(
        int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
        int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
```

The WASD fallback is hardcoded and bypasses `Controls` (`scripts/controls.gd`), which is where every other key binding lives. It also isn't rebindable, doesn't work on a gamepad-only path, and `Input.is_key_pressed` is not layout-aware (AZERTY users get `A`/`Q` confusion on a QWERTY binding). The rest of the game routes input through named actions.

**Fix:** register `move_left`/`move_right`/`move_up`/`move_down` in `Controls._add()` with both the WASD keycodes and the arrow keycodes, and read them with `Input.get_vector("move_left", "move_right", "move_up", "move_down")`. This removes the fallback branch entirely and makes WASD rebindable.

---

## 4. MINOR

**N1 — `Sfx.play` allocates a player node per sound.** `scripts/sfx.gd:11-17`. A new `AudioStreamPlayer` plus a `load()` for every footstep (every0.3 s while walking, `player.gd:44`), click, and hit. A small pool of reusable players with the streams cached in a `static var` would remove the churn.

**N2 — `Sfx.play` indexes `FILES[key]` unguarded.** `scripts/sfx.gd:14`. An unknown key is a hard error. There are ~15 call sites with string literals, so a typo is easy: use `FILES.get(key, "")` and `push_warning` on a miss.

**N3 — `Music.play` mutates the shared cached `AudioStreamMP3`.** `scripts/music.gd:26-28`. `load()` returns the shared resource, so `s.loop = true` mutates it globally. It works by accident; `s.duplicate()` with `loop` set on the copy is correct.

**N4 — `BattleUI._apply_button_style` picks a theme via `md5_buffer()[0] % 3`.** `scripts/battle_ui.gd:72`. The distribution is fine and it is stable per enemy, but the expression is opaque to a reader. `key.hash() % 3` is equally stable within a Godot version and self-explanatory. Also, `load()` for the three button textures runs on every battle; a `static var` cache of the three `Theme`s avoids rebuilding the `Theme` and `StyleBoxTexture` objects.

**N5 — `_battle_backdrop` and `_explore_music` use `floor_num` directly rather than a helper.** `scripts/level.gd:388-395`. `((floor_num - 1) / 5) % N` appears in three places (`_crypt`, `_spawn_floor`, `_battle_backdrop`). Extracting `func _floor_theme() -> int` would keep them in sync.

**N6 — `character_data.gd:177` truncates defense when halved.** `int(defense * 0.5)` means defense 1 → 0 under "debil", so `preview_damage` returns `max(1, amount)` — full damage. A balance nit rather than a bug, but `maxi(1, ...)` would make the intent hold.

**N7 — `battle_ui.gd:279` indexes `targets[0]` without a guard.** `show_target_menu` is only called when `alive.size() > 1` (`battle_system.gd:316`), so it's safe today, but the method is public and an empty array would be an index error.

**N8 — `battle_ui.gd:258` does a linear dictionary scan per character.** `if c in intent_rows` is O(n) inside a loop over all characters. With ≤5 enemies this is irrelevant, but `intent_rows.has(c)` is the idiomatic form.

**N9 — `level.gd:431` is a dense one-liner.** `_make_area(45, 16, Vector2(160, 198), func(_a): _go_floor(maxi(1, run_floor))).get_child(0).visible = false` — the trailing `.get_child(0).visible = false` hides the trapdoor sprite because the hub background already draws it. Worth a named variable or a comment; the intent isn't obvious.

**N10 — `tools/make_floor1.py:31` computes the background median from only 3 of 4 corners.** The bottom-right corner is omitted while the docstring says "inundación desde los bordes". Probably intentional (the source JPEG's frame) but undocumented — and inconsistent with the other three.

**N11 — `tools/make_floor1.py:44-52` is O(n²)-ish in the dilation.** 15×15 = 225 full-image OR operations over a 307×307 array. For a one-off asset tool this is seconds, not a problem, but `scipy.ndimage.binary_dilation` would be a one-line improvement.

**N12 — `tests/` has no test runner.** Each file is a standalone `SceneTree` script invoked manually (`Godot --headless --path . --script tests/test_X.gd`) per the usage comment at the top of each. There's no `.github/` directory, so **nothing runs these automatically** — 12 test files that only run if someone remembers to run them. A `tools/run_tests.sh` that loops over `tests/test_*.gd` and fails on non-zero exit, wired into CI, would make them count.

**N13 — `tests/test_flow.gd:48` asserts on button text that the test itself mutates.** `if not SaveGame.exists() or btns[1].text == "Nueva partida"` — `btns[1].pressed.emit()` (line 47) changes the text to `"¿Seguro? Se borra todo"`, and the assertion checks the *mutated* value. The intent ("la nueva partida no arrancó") is met, but reading it requires tracing the mutation order.

---

## Summary

| Severity | Count | Most important |
|---|---|---|
| CRITICAL | 2 | Stale floor areas binding E to the wrong action; corrupt-save crash on startup |
| HIGH | 5 | Unclamped meta upgrade levels; `_go_floor` re-entry; repeatable ambush; dangling `current_enemy`; unguarded `equip()` |
| MEDIUM | 7 | `find_by_id` allocation churn; reference-based inventory identity; `_free_pos` fallback; `class_name Level`; backdrop caching; shop feedback; hardcoded WASD |
| MINOR | 13 | Polish, plus **no automated test runner** (N12) |

**If you fix three things:** C1 (stale areas — affects every descent from the hub), H1 (unclamped meta levels — a one-line clamp that closes a balance exploit), and H2 (`_go_floor` re-entry — a two-line guard that prevents a skipped floor).

The test suite is a genuine strength — `test_floor_reachability.gd` flood-fills 60 generated floors, `test_intents.gd` verifies that displayed intent matches executed damage, and `sim_balance.gd` simulates full campaigns with the real `BattleSystem`. Extending the reachability test to assert that no `floor_obj` overlaps the player's `start_pos` would have caught C1 automatically, and it's the highest-value addition to make.