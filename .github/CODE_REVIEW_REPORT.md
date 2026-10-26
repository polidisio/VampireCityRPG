# Code Review Report: VampireCityRPG
Generated: 2026-10-27T00:11:37.731350

I've read all 20 relevant source files (`scripts/*.gd`, `tests/*.gd`, `tools/*.py`). Here's my report.

---

# Code Review: VampireCityRPG

**Scope:** 26 GDScript files, 15 test files, 3 Python tools (~4,500 LOC). All files reviewed.
**Overall:** This is a well-structured, thoroughly commented codebase with genuine test coverage. No remote-execution or classic injection vulnerabilities (no `exec`/`eval`/network calls; the only I/O is a local `user://save.json` and read-only asset `load()`s). The issues below are mostly robustness, input validation on the save file, and allocation churn.

---

## 1. CRITICAL issues (must fix)

### C1. Save file is trusted without type validation → script errors on load
**File:** `scripts/save_game.gd:46-51`

```gdscript
c.relics = d.get("relics", [])       # c.relics is a typed Array
c.pacts  = d.get("pacts", [])
for slot in d.get("equipment", {}):
    c.equipment[slot] = ItemData.find_by_id(d.equipment[slot])
```

`c.relics`/`c.pacts` are declared `Array` (`character_data.gd:21-22`). Assigning a JSON string/number to a typed property raises a runtime *"Trying to assign value of type String to a variable of type Array"* error and aborts `load_game()`. Similarly `d.get("levels", {})` in `meta.gd:70-71` iterates a non-dict as characters → `int(d.levels["a"])` crashes, and `Meta.last_pacts` / `QuestLog.claimed` get the same unchecked treatment.

The save lives in `user://` and is user-editable. A truncated or hand-edited save currently bricks the game at startup. **CLAUDE.md explicitly requires "Validar input antes de procesar".**

**Fix:** Validate each field's type before assignment.

```gdscript
var relics = d.get("relics", [])
c.relics = relics if relics is Array else []
c.pacts = d.get("pacts", []) if d.get("pacts", []) is Array else []
```

Apply the same guard in `Meta.from_dict` (`meta.gd:65-72`), `QuestLog.from_dict` (`quest_log.gd:35-40`), and validate `d["equipment"]` is a Dictionary before iterating.

### C2. `SaveGame.save()` can crash the game on write failure
**File:** `scripts/save_game.gd:19-20`

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

`FileAccess.open` returns `null` on failure (read-only media, permissions, disk full). The next line dereferences null → hard crash, and the failure happens at an arbitrary point in gameplay (every `_save()` call). This is exactly the "missing error handling" class of bug.

**Fix:**
```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
if f == null:
    push_error("No se pudo guardar: %s" % error_string(FileAccess.get_open_error()))
    return
f.store_string(JSON.stringify(d))
```

### C3. `Sfx.play()` / `Music.play()` have no key or null-stream validation
**Files:** `scripts/sfx.gd:11-17`, `scripts/music.gd:26-29`

```gdscript
p.stream = load("res://assets/audio/" + FILES[key] + ("" if "." in FILES[key] else ".ogg"))
```

Three failure modes, all unguarded:
- `FILES[key]` with an unknown key → `Invalid get index` error, `null` → string concat on null.
- `load()` returns null if the asset is missing → `p.stream = null` → `p.play()` errors.
- `Music.play`: `var s: AudioStreamMP3 = load(...)` — if the track doesn't exist, `s` is null → `s.loop = true` crashes.

A missing or renamed asset (the single most likely asset-side regression) crashes the game instead of degrading to silence.

**Fix:** Guard the dictionary lookup and the loaded stream in both functions.

### C4. `CharacterData.equip()` crashes on a non-equipment item
**File:** `scripts/character_data.gd:185-194`

```gdscript
func equip(item: ItemData) -> ItemData:
    var slot = {ItemData.ItemType.WEAPON: "weapon", ...}[item.type]
    var old: ItemData = equipment[slot]
```

If `item.type` is `CONSUMABLE`, the dictionary lookup yields `null` and `equipment[null]` → *"Invalid key"* runtime error. Currently unreachable only because `InventoryMenu._on_item` (`inventory_menu.gd:66-73`) branches on type first. Any new caller of `equip()` — or a save that deserializes a consumable into a slot — crashes. The item is also not removed from the player's inventory when this path is hit.

**Fix:** Add an explicit guard at the top:
```gdscript
const SLOTS = {ItemData.ItemType.WEAPON: "weapon", ItemData.ItemType.ARMOR: "armor", ItemData.ItemType.ACCESSORY: "accessory"}
if not SLOTS.has(item.type):
    return null
```

---

## 2. HIGH issues (should fix)

### H1. `title.gd` — "new game" confirmation is a one-shot latch that never resets
**File:** `scripts/title.gd:37-42`

```gdscript
new_btn.pressed.connect(func():
    if SaveGame.exists() and new_btn.text == "Nueva partida":
        new_btn.text = "¿Seguro? Se borra todo"
        return
    DirAccess.remove_absolute(SaveGame.PATH)
    _start())
```

The button text is the confirmation state and is **never reset**. Once armed, the button stays lethal for the rest of the session: a player who clicks "Nueva partida" by accident, changes their mind, clicks "Continuar" or any other control, and then clicks that button again wipes their save with no warning. The state should live in a separate variable and reset on any other interaction.

### H2. `DialogBox._ready()` indexes an empty child list
**File:** `scripts/dialog_box.gd:42`

```gdscript
row.get_child(0).grab_focus.call_deferred()
```

If `actions` is empty **and** `closable == false`, `row` has zero children → *"Index 0 out of size 0"*. `_choose()` (`level.gd:699-706`) builds exactly such a dialog when `offers` is empty — currently guarded at both call sites (`level.gd:654`, `level.gd:710`), but one missed guard turns into a crash. Make the failure explicit rather than incidental:

```gdscript
if row.get_child_count() > 0:
    row.get_child(0).grab_focus.call_deferred()
```

### H3. `equip()` has no double-equip protection → stat duplication
**File:** `scripts/character_data.gd:185-194`

Equipping the *same* item instance that is already in the slot subtracts its bonus and re-adds it (net zero) but replaces the slot entry — however `InventoryMenu._on_item` (`inventory_menu.gd:70-73`) then appends the old item back to the backpack while the *new* one stays equipped, and the old instance's bonus was already subtracted. Because `ItemData` instances are recreated per `find_by_id` call (see H5), the player can end up with two copies of the same bonus source in circulation. Worth an explicit "already equipped" check.

### H4. `Music.play()` mutates a shared cached resource
**File:** `scripts/music.gd:26-28`

```gdscript
var s: AudioStreamMP3 = load("res://assets/audio/music/%s.mp3" % key)
s.loop = true
```

`load()` returns the **cached** resource. Setting `loop = true` mutates the shared instance for the whole process — any other code that plays that track gets looping as a side effect. Use `duplicate()` before mutating, or set the loop on the player instead.

### H5. `ItemData.get_all_*()` recreates every item on every call
**File:** `scripts/item_data.gd:81-127`

Every call allocates a fresh array of brand-new `ItemData` objects, and `find_by_id()` calls all four lists. This runs in hot-ish paths:
- `BattleSystem.generate_drops()` (`battle_system.gd:369-375`) on every victory
- `SaveGame.load_game()` (`save_game.gd:52-55`) once per saved item
- `ShopMenu.stock()` at menu open

**Fix:** cache the lists in a `static var` and return the cached instances. This also fixes the identity problem in H6.

### H6. `Inventory` uses identity comparison on objects that are recreated
**Files:** `scripts/inventory.gd:15-24`, `scripts/item_data.gd:122-127`

`remove_item()` uses `items.find(item)` and `has_item()` uses `items.has(item)` — both are **identity** comparisons for `Object`s (no `_equals` override on `ItemData`). But `ShopMenu._buy` adds `ItemData.find_by_id(item.id)` — a *different instance* than the shop's `item`. `test_shop.gd:22` already works around this with an `or` fallback, which is a signal the authors hit the trap.

Consequence: `has_item()` returns false for any item obtained outside the inventory, and any future code doing `if inv.has_item(ItemData.find_by_id("x"))` silently misbehaves. **Fix:** compare by `id` instead of identity, or (preferred) make the item lists cached singletons per H5.

---

## 3. MEDIUM issues (consider fixing)

### M1. `level.gd` — `_free_pos()` can return a position inside a wall
**File:** `scripts/level.gd:379-385`

The 60-iteration loop returns the last sampled point even when no valid position was found. Enemies, the elite, the boss and event objects can then spawn embedded in geometry. There is no fallback that guarantees a valid spawn.

### M2. Node churn in the battle UI hot path
**File:** `scripts/battle_ui.gd:239-270`

`update_stats()` runs on every turn and every damage event. For each character it `_clear_row()`s the status row (queue_free of children) and rebuilds `TextureRect`/`Label` nodes from scratch. Similarly `_show_list()` (`battle_ui.gd:308-309`) `queue_free`s the old buttons but they remain children of the `GridContainer` until end-of-frame, so the list transiently contains stale buttons (visible as a duplicate frame, and stale buttons can steal focus). Prefer updating existing child nodes in place, or `remove_child()` + `queue_free()`.

### M3. `battle_system.gd` — no index validation on player actions
**File:** `scripts/battle_system.gd:116-133`, `135-156`

```gdscript
var target = enemy_team[target_index]      # no bounds / alive check
var skill = attacker.skills[skill_index]   # no bounds check
```

`_pick_target` (`battle_system.gd:311-319`) calls `on_pick.call(first_alive_enemy())` when `alive.size() <= 1`; `first_alive_enemy()` returns **-1** when nothing is alive. GDScript accepts `enemy_team[-1]` as the *last* element, so a stale click would hit a dead enemy instead of erroring. Add explicit guards (`if target_index < 0 or target_index >= enemy_team.size(): return`).

### M4. `player_use_skill` spends MP before validating the action
**File:** `scripts/battle_system.gd:142-147`

`use_mp()` deducts the cost, then `_use_skill()` runs. If the target index is invalid the MP is lost for no effect. Reorder so validation precedes the deduction.

### M5. `level.gd` — `_note()` allocates a `SceneTreeTimer` per message
**File:** `scripts/level.gd:719-724`

Each notification creates a 3-second timer that stays alive until it fires. On a busy floor this accumulates timers. A single reusable timer with a timestamp would be cheaper and simpler.

### M6. `SaveGame.load_game()` silently drops gear whose id no longer exists
**File:** `scripts/save_game.gd:50-51`

`ItemData.find_by_id()` returns `null` for a removed/renamed item, so the slot becomes empty — but the saved `attack`/`defense` already include that item's bonus. The player keeps a permanent stat bonus for gear they no longer have. Consider recomputing stats from equipment on load rather than trusting the saved totals.

### M7. `level.gd` — `_show_class_select()` closes over `data` in a signal callback
**File:** `scripts/level.gd:118-148`

The `b.pressed` lambda is `async` (it awaits `menu.confirmed`) and mutates `player.character_data`, `busy`, and `player.process_mode` after the await. If the player triggers `interact`/`hub` during that window, `busy` is still `true` so input is blocked — this works, but the state machine is spread across an `await` boundary with no re-entrancy guard. Worth an explicit comment or a small state enum.

### M8. `tools/make_ui.py` writes to a CWD-relative path
**File:** `tools/make_ui.py:37`

```python
f.save(f"assets/ui/btn_{name}_{st}.png")
```

`make_floor1.py` and `make_stairs.py` both anchor to `os.path.dirname(__file__)`, but `make_ui.py` does not. Running it from any directory other than the repo root silently writes files to the wrong place (or fails).

### M9. `tools/make_floor1.py` indexes a detection list without bounds checks
**File:** `tools/make_floor1.py:74`

```python
for i, (x0, y0, x1, y1) in enumerate([boxes[k] for k in keep]):
```

`keep` contains hardcoded indices up to 13. If the flood-fill / connected-component detection returns fewer boxes than expected (different source image, threshold tweak), this raises `IndexError` after partially writing sprites. Validate `max(keep) < len(boxes)` up front.

---

## 4. MINOR suggestions (nice to have)

- **`scripts/battle_ui.gd:71-85`** — `_apply_button_style()` derives the button theme from `key.md5_buffer()[0] % 3`. Deterministic but arbitrary and opaque; the mapping is invisible to the player and impossible to reason about when tuning. A comment or an explicit table would help. Also, this replaces `theme` wholesale each battle — the previous theme is not restored on exit.
- **`scripts/battle_ui.gd:278`** — `show_target_menu` accesses `targets[0]` unguarded; add a guard for an empty list.
- **`scripts/battle_ui.gd:206`** — `spr.texture.get_height()` will crash if a texture failed to load. Same at `battle_ui.gd:108`.
- **`scripts/character_data.gd:146`** — `add_status` uses `maxi(turns, existing)`, so applying a shorter bleed never shortens it. Intentional-looking, but not obvious; a one-line comment would prevent a future "fix".
- **`scripts/level.gd:431`** — `_make_area(...).get_child(0).visible = false` hides the stairs sprite, but the Area2D's collision shape remains, so the invisible area still triggers the floor transition. This is presumably intended, but the code reads as if only the visual is being suppressed.
- **`scripts/enemy_ai.gd:10-11`** — `level` is typed as a bare `Node` and duck-typed throughout (`level.busy`, `level.player`, `level.blocked`). Typing it as the level's class would surface refactor breakage at compile time.
- **`scripts/player.gd:19`** — `sprite.material.shader = load("res://assets/walk.gdshader")` — the shader file exists, but a null-check after `load()` is cheap insurance (same as C3).
- **`tests/sim_balance.gd:173`** — `meta.streak = 0 if ok else meta.streak` — the `else` branch is a no-op assignment (the `break` above means `ok` is always `true` here). Simplify to `meta.streak = 0`.
- **`tests/*.gd`** — all tests rely on `assert()`, which is compiled out in release builds. Add a note in the test header that they require a debug build.
- **`scripts/controls.gd:10-12`** — the `node_added` hook connects a click sound to every `BaseButton` added anywhere in the tree, including menus that are later freed. The connection dies with the node, so it's correct, but a scene-tree-wide side effect from a static utility is a smell. A dedicated `Button` subclass or a theme-based approach would be more contained.
- **`scripts/item_data.gd:31-35`** — the tint loop is a per-pixel Python-style loop in GDScript over every pixel of the icon. It's cached in `_icons`, so it runs once per item id — acceptable, but `Image` has no vectorized multiply, so this is close to as good as it gets.

---

## Summary table

| Severity | Count | Items |
|---|---|---|
| CRITICAL | 4 | C1 save type validation, C2 save write null-check, C3 audio null/key validation, C4 `equip()` type guard |
| HIGH | 6 | H1 title confirm latch, H2 empty dialog row, H3 double-equip, H4 shared resource mutation, H5 item re-creation, H6 identity comparison |
| MEDIUM | 9 | M1–M9 |
| MINOR | 11 | listed above |

**Overall assessment:** No security vulnerabilities of substance — no network I/O, no `exec`, no user input reaching a filesystem path (the save path is a hardcoded constant). The real risk surface is **robustness against malformed saves and missing assets**, which C1–C4 address. The codebase is otherwise well-factored (clear separation between data/battle/UI layers), has meaningful test coverage of balance, flow, targeting, intents, pacts and floor reachability, and the Spanish comments explain *why* rather than *what*. The MEDIUM/MINOR items are polish, not blockers.