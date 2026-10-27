# Code Review Report: VampireCityRPG
Generated: 2026-10-28T00:15:04.412253

I've read the source (scripts/, tests/, tools/) and cross-checked assets, scenes, and project settings. Here's the review.

---

# Code Review — VampireCityRPG

Scope: 28 files in `scripts/`, 14 in `tests/`, 3 in `tools/`. ~4,300 lines of GDScript. The code is generally clean, well-commented (Spanish, consistent with the project), and has a real test suite. Findings below.

---

## 1. CRITICAL issues

**None.** No security vulnerabilities (no network, no external input, no credentials), no unbounded memory growth, and no save-file corruption paths that I could find. The code is safer than typical for a game jam project.

---

## 2. HIGH issues

### H1 — The "Ayuno" pact is bypassable via the inventory menu
`scripts/inventory_menu.gd:66-74`

The battle menu blocks item use under the pact (`scripts/battle_system.gd:328-330`), but the inventory menu does not:

```gdscript
func _on_item(item: ItemData):
	if item.type == ItemData.ItemType.CONSUMABLE:
		character.use_item(item)   # <- no pact check
```

The pact is described as *"Sin objetos: ni usarlos ni llevarlos"* (`scripts/pacts.gd:10`), so a player can open the inventory mid-run and drink potions, defeating the risk/reward choice.

**Fix:** mirror the battle check — e.g. `if item.type == ItemData.ItemType.CONSUMABLE and character.pacts.has("ayuno"): return` (with a log message), or move the check into `CharacterData.use_item()` so both callers are covered.

### H2 — `SaveGame.save()` does not check for a null file handle
`scripts/save_game.gd:19-20`

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

If the write fails (read-only home dir, disk full, permissions), `FileAccess.open` returns `null` and this crashes the game *at an arbitrary moment* — including mid-battle from `_save()` calls in `scripts/level.gd`. This is the single most likely crash in the codebase, and it loses the whole run.

**Fix:**
```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
if f == null:
	push_error("No se pudo guardar: %s" % error_string(FileAccess.get_open_error()))
	return
f.store_string(JSON.stringify(d))
f.close()
```

The same unchecked pattern exists in `scripts/title.gd` (no — that one is `DirAccess.remove_absolute`, fine) and in the test helpers `tests/test_run.gd`, `tests/test_meta.gd`, `tests/test_flow.gd`.

### H3 — `load_game()` trusts the shape of nested JSON
`scripts/save_game.gd:26-56`

Only the top level is validated (`typeof(d) != TYPE_DICTIONARY or not d.has("gold")`). Everything nested is trusted:

- `d.get("meta", {})` → `Meta.from_dict()` calls `d.get("levels", {})` and iterates it — if `meta` is a string, `d.levels[k]` throws.
- `d.get("quests", {})` → `QuestLog.from_dict()` calls `.get("counters", {})` on it.
- `d.get("relics", [])` / `d.get("pacts", [])` are assigned straight to typed-ish fields; a string would silently make `relics.has(id)` a *substring* test rather than a membership test.
- `c.equipment[slot] = ItemData.find_by_id(...)` → `find_by_id` can return `null`, and `inventory_menu.gd:39` then calls `c.equipment[slot].name` on it → crash.

A truncated or hand-edited `user://save.json` produces a crash instead of the intended graceful "corrupt → start fresh" path that the doc comment on line 22 promises.

**Fix:** validate types at each level (`typeof(x) == TYPE_DICTIONARY` before `.get`), coerce `relics`/`pacts` with `Array(...)`/type checks, and skip null equipment entries.

---

## 3. MEDIUM issues

### M1 — Enemy areas and interaction areas share a collision layer, so walls can start battles
`scripts/level.gd:264` + `scripts/enemy_ai.gd:107`

Every enemy is an `Area2D` with the default `collision_mask = 1`, and it starts a battle on *any* `body_entered`:

```gdscript
a.body_entered.connect(func(_b): if not busy: on_enter.call(a))
```

Walls and the seal door are `StaticBody2D` on layer 1 (`_add_block` at `scripts/level.gd:308`, `_build_seal` at `scripts/level.gd:466`), so they are detected too. The AI avoids walls with an 8 px margin (`enemy_ai.gd:107`), while the elite's area half-extent is `24 * 0.7 / 2 = 8.4` px (`scripts/level.gd:239`) — the elite can legally settle 8.0–8.4 px from a wall and overlap it, firing `body_entered` and opening a fight against a wall. The elite also *presses* against walls while chasing, so this is reachable in practice.

**Fix:** either give enemies their own collision layer, or filter the signal: `if _b is Player: on_enter.call(a)`. The same filter fixes the cosmetic issue of the NPC "E: ..." label appearing when the player brushes a wall.

### M2 — The seal's warning zone detects its own door body
`scripts/level.gd:492-504`

```gdscript
var zone = Area2D.new()          # child of `door`
...
zone.body_entered.connect(func(_b):
	if not has_key:
		_note("El sello resiste. Busca al élite del piso."))
```

The zone's shape (`r.size.x + 12` wide) overlaps the door's own `CollisionShape2D` sibling. Godot's physics doesn't care about tree hierarchy, so `body_entered` fires with the door body the moment the floor is built — the player sees *"El sello resiste"* immediately on entering every floor.

**Fix:** `if not has_key and _b is Player:` (or move the zone out of the door and give it a layer only the player occupies).

### M3 — `Music.play()` and `Sfx.play()` will crash on a missing file
`scripts/music.gd:26`, `scripts/sfx.gd:14`

```gdscript
var s: AudioStreamMP3 = load("res://assets/audio/music/%s.mp3" % key)
s.loop = true
```

`load()` returns `null` for a missing path → `null.loop = true` is a hard crash. All current keys resolve (I verified `assets/audio/music/` contains `battle*`, `boss*`, `explore`, `deep`, `title`, and every entry in `Sfx.FILES`), but the code has no guard, and `Music.pick()` indexes `POOLS[pool]` unguarded too — a typo in a theme name is a crash rather than a silent fallback.

**Fix:** null-check the load and `push_warning` + return.

### M4 — `Icons.tex()` throws on an unknown glyph name
`scripts/icons.gd:26`

`var rows: Array = GLYPHS[name]` — a missing key is a runtime error, not a default. Every current caller uses a valid name (`Icons.STATUS` and `skill_icons()` only emit `sword/heart/drop/skull/up/down/stun/flame`), but `Icons.tex()` is a public helper and a future status name would crash the battle UI.

**Fix:** `if not GLYPHS.has(name): return null` and have the callers handle null.

### M5 — `ItemData.find_by_id()` allocates 25 objects per lookup
`scripts/item_data.gd:122-127`

Every call rebuilds all four item lists (7 weapons + 6 armors + 4 accessories + 8 consumables = 25 `ItemData` instances). It's called in a loop over every saved item (`scripts/save_game.gd:52-55`), per battle drop (`scripts/battle_system.gd:369-375`), per purchase (`scripts/shop_menu.gd:81`), and per quest reward (`scripts/level.gd:782`). It also makes item identity fragile — `find_by_id` returns a *different instance* than the one already in the inventory, so `Inventory.remove_item()` (which uses `Array.find`, i.e. reference equality) only works because the callers happen to pass the stored instance.

**Fix:** cache the four lists as `static var` and return a stable instance from `find_by_id`.

### M6 — Failing `assert()` in a test hangs the run instead of failing it
`tests/test_run.gd`, `tests/test_meta.gd`, `tests/test_shop.gd`, `tests/test_intents.gd`, `tests/test_targeting.gd`, `tests/test_pacts.gd`, `tests/test_content.gd`, `tests/test_inventory_relics.gd`, `tests/test_dialogues.gd`, `tests/test_npc_collision.gd`, `tests/test_floor_reachability.gd`, `tests/test_floor_features.gd`

In Godot 4 a failed `assert` aborts the current function. In a `SceneTree._init()` script that means `_init` aborts, `quit()` at the end is never reached, and the main loop runs forever — the test process hangs instead of exiting non-zero. `tests/test_flow.gd` gets this right (it has its own `fail()` helper that calls `quit(1)`); the other files don't.

**Fix:** add a shared helper (`func fail(msg): print("FAIL: ", msg); quit(1)`) and use it in place of raw `assert`, or wrap the body in `OS.set_exit_code(1)` on error.

### M7 — `scripts/level.gd` is a 879-line God class
`scripts/level.gd`

It owns floor generation, walls, collision, NPCs, events, the elite, the boss, the seal, the class-select screen, the hub, dialogue dispatch, quest claiming, the shop, the altar, the run lifecycle, and saving. At least five concerns could be extracted: floor generation (`_build_walls`, `_placeable`, `_free_pos`, `_scatter_decals`), the seal/boss room, NPC/event spawning, the dialogue+quest layer, and the run lifecycle (`_end_run`, `_on_battle_ended`).

The highest-value split is the run lifecycle — `_on_battle_ended` (line 828) is a 25-line `await` chain that mixes victory rewards, relic pickup, level-up spending, stairs creation, and defeat handling.

**Fix:** extract at least `floor_builder.gd` and `run_lifecycle` before the file grows further.

---

## 4. MINOR suggestions

**M8 — `scripts/battle_ui.gd` reaches up to its parent for game logic.** `update_stats()`, `show_target_menu()`, `show_player_menu()` and `show_skill_menu()` all do `var system: BattleSystem = get_parent()`. This couples the view to its parent node's concrete type; passing the needed values (or an interface) as parameters would remove the coupling and make `battle_ui` testable standalone.

**M9 — `scripts/battle_system.gd` guards `ui` inconsistently.** `start_battle` checks `if ui:` before use (line 51, 55), but `next_turn` (line 85), `player_attack` (line 126) and `_use_skill` (line 221) dereference `ui` unguarded. `_ready` already `push_error`s and continues when `ui` is missing, so a broken scene leads to a null-deref crash later. Either bail out of `_ready` or make the accessors null-safe.

**M10 — Confusing parameter naming in `scripts/battle_system.gd:357`.**
```gdscript
_pick_target(func(t): player_use_skill(index, t), skill.damage)
```
`t` reads like a `CharacterData`, but `_pick_target` passes an *index* (`alive[k]`, line 319). Rename to `idx` to avoid a future bug when someone "fixes" it.

**M11 — Dead code.**
- `scripts/inventory.gd:3,13,19` — the `inventory_updated` signal is emitted but never connected.
- `scripts/inventory.gd:23,29,32,35` — `has_item`, `get_weapons`, `get_armors`, `get_accessories` have no callers.
- `scripts/character_data.gd:161` — `status_text()` unused.
- `scripts/player.gd:93` — `get_input_direction()` unused.

**M12 — `scripts/battle_system.gd:274` — boss EXP is computed per enemy but `generate_drops()` (line 380) only checks `enemy_team[0].is_boss`.** Currently the boss is always the sole enemy so it works, but the two use inconsistent criteria. Worth a shared `has_boss` helper.

**M13 — `scripts/battle_system.gd:194-206` — `incoming_count()` and `incoming_damage()` each call `intent_info()` for every enemy**, and `intent_info` calls `preview_damage()`. This runs on every `update_stats()`, which is called several times per turn. Negligible at this scale (≤5 enemies), but `incoming_damage()` already computes everything `incoming_count()` needs — they could share one pass.

**M14 — `tools/make_ui.py` writes to a CWD-relative path** (`assets/ui/...`), while `tools/make_floor1.py` and `tools/make_stairs.py` correctly resolve paths relative to `__file__`. Running `make_ui.py` from anywhere but the repo root writes to the wrong place. Also, `tools/make_floor1.py:14` hardcodes `~/Downloads/nivel1` as the default source, and line 55 references `"decals..jpeg"` (double dot) — worth confirming that's the real filename and not a typo.

**M15 — `project.godot` sets `window/stretch/scale_mode="integer"` while `CLAUDE.md` describes the stretch mode as *"canvas_items (texto y arte a resolución de ventana, sin pixelado)"*.** The two contradict each other; the doc or the setting should be corrected.

**M16 — No CI.** The `tests/` suite is entirely manual (`Godot --headless --path . --script tests/test_x.gd`). A GitHub Actions workflow running each script would catch regressions — especially once M6 is fixed so failures exit non-zero.

**M17 — `scripts/level.gd:379-385` — `_free_pos()` has no guaranteed-valid fallback.** If all 60 attempts fail, it returns the last random point, which may be inside a wall. Rare, but for the boss it would place a 22 px-wide area overlapping a wall and (with M1 unfixed) instantly trigger the boss fight on floor entry. Adding a final "clamp to the nearest safe spot" would close it.

**M18 — `scripts/level.gd:80` — `cam.limit_right = int(floor_size.x)`** but the camera is a child of the player, so the limit is in world space while the viewport is 320×180. This works only because the player is clamped inside the room; worth a comment since it's non-obvious.

---

## Summary

The codebase is in good shape: consistent naming, useful Spanish comments that explain *why*, no credentials or external I/O, and a genuine test suite plus a balance simulator. The most likely real-world crashes are **H2** (null file handle on save) and **H3** (unvalidated save JSON) — both cheap to fix and worth doing before the next release. **H1** (Ayuno bypass) is the only gameplay-correctness issue. The architectural item to address soon is **M7**: `level.gd` is approaching a size where every change risks a regression.