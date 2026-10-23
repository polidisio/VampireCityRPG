# Code Review Report: VampireCityRPG
Generated: 2026-10-24T00:24:36.623195

I have read the full `scripts/` tree (28 files), `tests/` (13 files) and `tools/` (3 files). Here is the review.

---

# Code Review — VampireCityRPG

**Scope:** `scripts/` (28 `.gd`), `tests/` (13 `.gd`), `tools/` (3 `.py`). Assets/binary ignored.
**Overall:** The code is well organized (clear separation `CharacterData`/`BattleSystem`/UI, data-driven `Upgrades`/`Pacts`/`Dialogues`), consistent in style, and covered by a real headless test suite. No hardcoded secrets, no shell/SQL/eval injection surface (save file is the only untrusted input). The issues below are mostly robustness and maintainability, not broken logic.

---

## 1. CRITICAL — must fix

### 1.1 Save file is parsed with no schema validation → crash on load
**`scripts/save_game.gd:26-56`**

`load_game()` only checks `typeof(d) == TYPE_DICTIONARY and d.has("gold")`. Everything after is trusted blindly:

- `save_game.gd:38` — `int(d["class"])` is fine, but `save_game.gd:52-53` calls `ItemData.find_by_id(id)` where `id` comes straight from JSON. `find_by_id(item_id: String)` is typed, so a JSON number raises *"Invalid type in function 'find_by_id'"* → the game cannot start.
- `save_game.gd:46` — `c.relics = d.get("relics", [])`; if the value is a string/dict instead of an array, `relics.has(id)` fails at `character_data.gd:140`.
- `save_game.gd:32` — `Meta.from_dict(d.get("meta", {}))`; if `meta` is not a dict, `d.get("essence", 0)` errors (`meta.gd:67`).
- `save_game.gd:50` — `for slot in d.get("equipment", {})` accepts arbitrary slot names and injects bogus keys into `c.equipment`, which are then re-saved forever.

A truncated file (kill during write), a hand-edited file, or a future schema change bricks the game with no recovery path.

**Fix:** validate every field's type before use, and add a `"version": 1` key so the format can be migrated. Minimal shape:

```gdscript
static func _arr(d: Dictionary, k: String) -> Array:
	var v = d.get(k, [])
	return v if v is Array else []

c.relics = _arr(d, "relics").filter(func(r): return r is String)
c.pacts  = _arr(d, "pacts").filter(func(r): return r is String)
for id in _arr(d, "items"):
	var it = ItemData.find_by_id(id) if id is String else null
	if it: inv.items.append(it)
```

### 1.2 Save writes are unchecked and non-atomic → data loss
**`scripts/save_game.gd:19-20`**

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

- `FileAccess.open` returns `null` on failure (permissions, disk full, bad path). `f.store_string(...)` on null → *"Invalid call on a null instance"* → crash. The result is never checked anywhere in the codebase.
- There is no `f.close()`; the flush relies on the `FileAccess` refcount dropping at function exit. Combined with the non-atomic write, a crash/power loss mid-`store_string` leaves a truncated `save.json` — which then hits issue 1.1 on next launch.
- No backup copy of the previous save.

**Fix:** check for null and `push_error` on failure; write to `user://save.json.tmp`, `close()`, then `DirAccess.rename_absolute()` over the real file; optionally keep `save.json.bak`.

---

## 2. HIGH — should fix

### 2.1 `_note()` timer callback fires against a freed scene
**`scripts/level.gd:720-724`**

```gdscript
msg.text = text
get_tree().create_timer(3.0).timeout.connect(func():
	if msg.text == text:
		msg.text = "")
```

The timer is owned by the `SceneTree`, so it survives `reload_current_scene()` (called at `level.gd:865` on death) and `change_scene_to_file` (pause menu → title, `level.gd:178`). The lambda captures `self` (it reads the `msg` member), so once the level node is freed the callback runs against a freed instance → *"Attempt to call function on a previously freed instance"*. The death path calls `_note("+%d Esencia")` shortly before the reload, so this is reachable in normal play.

**Fix:** capture the label weakly and bail if it is gone, e.g. `var lbl := msg; get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(lbl) and lbl.text == text: lbl.text = "")`.

### 2.2 Recursion in `next_turn()` on dead actors
**`scripts/battle_system.gd:71-76`**

```gdscript
current_turn_index = (current_turn_index + 1) % turn_order.size()
var current_actor = turn_order[current_turn_index]
if current_actor.character.hp <= 0:
	next_turn()
	return
```

Dead actors are skipped by *recursion*, not iteration. With several corpses in the order this is N-deep recursion, and the `check_battle_end()` that should terminate the battle is skipped for the skipped actors. It also reads the turn order backwards: the corpse check happens before `check_battle_end()`, so a battle whose last enemy died to bleed at the start of its own turn goes through the recursion path rather than the end-of-battle path.

**Fix:** convert to a bounded loop — `for _i in turn_order.size(): advance the index, break when a living actor is found; if none, return`.

### 2.3 Negative index can silently hit the wrong enemy
**`scripts/battle_system.gd:147-148`, `battle_system.gd:317`, `battle_system.gd:355`**

`_pick_target` calls `on_pick.call(first_alive_enemy())` when ≤1 enemy is alive, and `first_alive_enemy()` returns `-1` when none are alive. `enemy_team[-1]` is valid GDScript — it is the **last** enemy, not an error. So `player_use_skill(index, -1)` can damage a corpse, and `_on_player_hit` (`battle_system.gd:215`) then fires the *Colmillo Voraz* relic heal on a dead target, i.e. free healing.

**Fix:** guard with `if target_index < 0: return` in `player_attack` / `player_use_skill`, and make `_pick_target` not call back when `alive.is_empty()`.

### 2.4 `player_inventory` may be `null` in the battle path
**`scripts/battle_system.gd:331`, `battle_system.gd:347`**

`start_battle(player, enemies, inventory = null)` allows a null inventory (several tests rely on it). `_on_item_pressed` guards with `if player_inventory else []`, but `_on_item_selected` (`battle_system.gd:347`) calls `player_inventory.remove_item(item)` unguarded, and `sim_balance.gd:87` invokes `_on_item_selected` directly.

**Fix:** `if player_inventory: player_inventory.remove_item(item)`, and mirror the guard used in `_on_item_pressed`.

### 2.5 `CharacterData.equip()` crashes on a non-equipment item
**`scripts/character_data.gd:185-194`**

```gdscript
var slot = {ItemData.ItemType.WEAPON: "weapon", ...}[item.type]
```

If `item.type == CONSUMABLE`, the dictionary lookup returns `null` and `equipment[null]` raises an invalid-key error. `InventoryMenu._on_item` currently routes consumables elsewhere, so this is only a latent trap for future callers.

**Fix:** `if item.type == ItemData.ItemType.CONSUMABLE: return null` at the top, or use a `match` with an explicit fallback.

### 2.6 `find_by_id` / `get_all_*` allocate a fresh object graph on every call
**`scripts/item_data.gd:81-127`**

Every `ItemData.get_all_consumables()` call constructs 8 `ItemData` objects; `find_by_id` builds **all four** lists (≈25 objects) just to find one item. These are called per shop purchase (`shop_menu.gd:81`), per saved item on load (`save_game.gd:53`), per drop roll (`battle_system.gd:369-370`) and per coffin (`level.gd:630`). It also means two equal items are never the same object, which is a subtle trap for `Inventory.remove_item` (reference-based `find`).

**Fix:** build the catalogue once into a `static var _by_id: Dictionary` (id → `ItemData`) and have `get_all_*` return the cached arrays. Keep the "same object" invariant so reference comparisons become safe.

### 2.7 No input validation on dialogue options
**`scripts/level.gd:762-763`**

```gdscript
actions.append([o.label, acts[o.do] if o.has("do") else _say.bind(npc, o.go)])
```

If an option has neither `"do"` nor `"go"`, `o.go` is an invalid-property error; if `o.do` is a string not in `acts`, `acts[o.do]` is a null-dictionary error. `tests/test_dialogues.gd` validates the *shipped* data, but there is no guard at the use site, so a future dialogue entry breaks the game at runtime.

**Fix:** `elif o.has("go"): ... else: continue` (or `push_warning`).

---

## 3. MEDIUM — consider fixing

### 3.1 `battle_ui.update_stats()` rebuilds every icon row on every call
**`scripts/battle_ui.gd:239-270`**

`update_stats()` is invoked on every turn, every damage event and every status change. Each call `queue_free()`s and re-creates the `TextureRect`/`Label` children of the incoming-damage, status and intent rows (`_clear_row` at :138, :254, :262). Because `queue_free()` is deferred, the old children are still parented when the new ones are added, so a row transiently shows both generations. Beyond the visual artefact, this is steady per-frame allocation churn.

**Fix:** keep the rows and update the existing children in place (resize/populate a pool of icons) instead of destroying and recreating them.

### 3.2 `_free_pos` can return a position inside a wall
**`scripts/level.gd:379-385`**

The 60-iteration loop breaks on the first valid point; if none is found it falls through and returns the **last random point**, which was never validated. An enemy or event can then spawn inside a block or on top of the player.

**Fix:** track the last *valid* candidate and return it; log a warning if none was found.

### 3.3 `EnemyAI` re-scans every wall every physics frame
**`scripts/enemy_ai.gd:106-107`**

```gdscript
return level.enemy_bounds().has_point(p) and not level.blocked.any(func(r): return r.grow(8).has_point(p))
```

With 4-6 enemies × 2 axes × 60 fps × ~40 wall rects this is thousands of `Rect2.grow()` allocations per second — and `Rect2.grow()` allocates a new `Rect2` on every element on every check.

**Fix:** precompute the grown rects once per floor (`blocked_grown`) and store them as plain floats; or build a coarse grid of blocked cells.

### 3.4 `enemy_ai.gd` reaches into `level` through untyped duck-typing
**`scripts/enemy_ai.gd:45, 49, 107, 110`**

`level: Node` is accessed as `level.busy`, `level.player`, `level.chase_grace_until`, `level.enemy_bounds()`, `level.blocked`. There is no compile-time or runtime check that the node has these members; a rename in `level.gd` becomes a runtime error only in the AI path.

**Fix:** type it `var level: Level` (or extract a small `FloorBounds` helper class) so the contract is explicit.

### 3.5 `InventoryMenu._on_item` equips without validating the item type
**`scripts/inventory_menu.gd:66-74`**

The `else` branch calls `character.equip(item)` for anything that is not a consumable, which is exactly the path that reaches 2.5. It also swaps the old item into the inventory but does not check whether that item is already equipped in another slot.

### 3.6 `SaveGame.load_game()` returns a 7-element `Array` accessed by index everywhere
**`scripts/save_game.gd:56`, `level.gd:53-58`, `tests/*.gd`**

`[null, inv, floor, max_floor, quests, run_floor, meta]` with `saved[1]`, `saved[6]`… is fragile: reordering the return silently corrupts every call site (several of them in tests).

**Fix:** return a small typed `SaveData` class (RefCounted) with named fields.

### 3.7 `Meta.from_dict` / `QuestLog.from_dict` trust their input
**`scripts/meta.gd:65-72`, `scripts/quest_log.gd:35-40`**

`m.levels[k] = int(d.levels[k])` assumes `d.levels` is a dict; `d.get("counters", {}).get(k, 0)` assumes the same. Same class of problem as 1.1.

### 3.8 `ShopMenu._buy` silently fails when the backpack is full
**`scripts/shop_menu.gd:76-79`**

The `return` gives no feedback (the header count is the only hint), and the gold is not spent — correct, but the player gets no explanation.

**Fix:** `ui.add_log`-style feedback ("Mochila llena").

### 3.9 `Sfx.play` leaks an `AudioStreamPlayer` if the node leaves the tree first
**`scripts/sfx.gd:11-17`**

`p.finished.connect(p.queue_free)` only fires if the stream finishes normally; if the parent is freed first (scene change), the player node is orphaned with its connection unresolved.

**Fix:** `p.tree_exited.connect(p.queue_free)` in addition.

### 3.10 `Music.pick` can return `null` for a single-track pool
**`scripts/music.gd:12-15`**

```gdscript
var opts: Array = POOLS[pool].filter(func(k): return k != _last.get(pool, ""))
_last[pool] = opts.pick_random()
```

If a pool ever has one track, `opts` becomes empty on the second call and `pick_random()` returns `null` → `Music.play(node, null)` → `load("res://assets/audio/music/.mp3")` fails. Currently `battle` has 5 and `boss` has 2, so it is safe — but it is one pool edit away from breaking.

**Fix:** `if opts.is_empty(): opts = POOLS[pool]`.

---

## 4. MINOR — nice to have

- **`scripts/controls.gd:10-12`** — the `tree.node_added` hook connects a click sound to *every* `BaseButton` ever created, including the ones created before `setup()` is called and any future ones. Consider a global theme `Button` sound or a dedicated `Button` subclass instead of a tree-wide hook.
- **`scripts/music.gd:19-29`** — `_player` is a `static var` living in `root`; it survives scene changes but is never freed, and `Music.play` is called from `title.gd`/`level.gd`/`battle_system.gd` with inconsistent keys (`"battle"` vs `"explore"`/`"deep"`). A small state machine for "explore / battle / boss" would remove the ad-hoc `theme` field threading through `level.gd:805` and `battle_system.gd:20`.
- **`scripts/level.gd:431`** — the hub stairs are an invisible trigger that changes floors as soon as the player walks over it (no key prompt, unlike the NPCs). The `_open_stairs` path at `level.gd:868-872` already goes to some length to avoid instant activation; the hub version has no such guard.
- **`scripts/level.gd:606` and `level.gd:618`** — the `holder` array + default-argument trick (`roll := randf()`) to defer a parameter is clever but hard to read. An explicit `_open_coffin_event(node)` wrapper would be clearer.
- **`scripts/level.gd:59-62`** — `saved[0] == null` vs `saved.is_empty()`: two different "no run" representations for the same state, checked in two places.
- **`scripts/battle_system.gd:65`** — `sort_custom` is not a stable sort, so enemies with identical speed get an arbitrary order that can change between the displayed intent and the execution.
- **`scripts/character_data.gd:149-159`** — `tick_statuses()` returns log lines ("X sangra") that `battle_system.gd:83` discards; the bleeding is only communicated through the floating damage number. Either surface the lines or drop the return value.
- **`tests/sim_balance.gd:22`** — `randomize()` makes balance regressions non-reproducible. Allow a `SEED` environment variable.
- **`tests/`** — no CI configuration and no runner script; the 12 headless tests must be invoked one by one by hand. A `tools/run_tests.sh` looping over `tests/test_*.gd` (and a CI job) would prevent regressions.
- **`tools/make_floor1.py:34`** — the flood-fill queue is seeded only on the left/right edges (`for y ... for x in (0, w-1)`), although the docstring says "inundación desde los bordes"; background reachable only through the top/bottom edges is not removed.
- **`tools/make_floor1.py:85`** — `sheet("decals..jpeg", ...)` has a double dot; worth verifying that is the real filename and not a typo for `decals.jpeg`.
- **`tools/make_floor1.py:44-68`** — `components()` is a pure-Python BFS over every pixel; it works but is the slowest part of the tool by a wide margin. `scipy.ndimage.label` would be ~100× faster if SciPy is acceptable as a dependency.

---

## Summary

The game code is in good shape for its scope: consistent conventions, no secrets, no injection surface, and a genuinely useful headless test suite. The two things I would fix before anything else are **1.1/1.2** (the save file is the only untrusted input in the whole project, and it is currently neither validated nor written safely — a corrupted save bricks the game), and **2.1** (the `_note` timer writing to a freed scene is reachable in normal play via the death/reload path). The rest are robustness and polish items that can be scheduled.