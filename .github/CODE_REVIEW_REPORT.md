# Code Review Report: VampireCityRPG

Generated: 2026-10-22T22:42:09Z by automated nightly review (Claude Code / MiniMax-M2.7)

Reviewed: 27 GDScript files in `scripts/`, `tests/`, `tools/`.

# Revisión de código — VampireCityRPG

**Alcance:** 27 archivos `.gd` en `scripts/`, `tests/`, `tools/` (leídos completos). Sin hallazgos de seguridad graves: no hay red, entrada de usuario ni credenciales; el "ataque" de superficie es el archivo de guardado JSON, que sí está validado.

---

## 1. CRITICAL (must fix)

### 1.1 `scripts/save_game.gd:51` — corrupt save can set `equipment` slot to `null` and crash the inventory menu
```gdscript
for slot in d.get("equipment", {}):
    c.equipment[slot] = ItemData.find_by_id(d.equipment[slot])
```
`find_by_id` returns `null` for an unknown id, so `c.equipment[slot]` may become `null` — fine. But the real bug: if the save contains an **unknown slot key** (e.g. `"ring"`), `c.equipment["ring"] = null` adds a key to the `equipment` Dictionary. `SaveGame.save` then iterates `for slot in c.equipment` and writes it back, and `inventory_menu.gd:39` does `c.equipment[slot].name` — for the three known slots this is guarded, but the dictionary now has 4 keys and `equip()` at `character_data.gd:186` maps by type, so behaviour diverges silently.

Worse: `find_by_id` is called with `d.equipment[slot]` which may be `""` (the empty-string sentinel written for an empty slot). `find_by_id("")` returns `null` — correct — **but** if the JSON has `"equipment": {"weapon": null}`, `d.equipment[slot]` is `null` and `find_by_id(null)` will throw a type error on the `String` parameter.

**Fix:**
```gdscript
for slot in ["weapon", "armor", "accessory"]:
    var id = str(d.get("equipment", {}).get(slot, ""))
    if id != "":
        var it = ItemData.find_by_id(id)
        if it:
            c.equipment[slot] = it
```
Also guard the whole file parse with `JSON.parse_string` returning `null` (already done via `typeof(d) != TYPE_DICTIONARY`) and each nested `d.get(...)` with a type check.

### 1.2 `scripts/level.gd:833` — `current_enemy` can be `null` in `_on_battle_ended`
```gdscript
var gain = _gain_essence(battle_system.enemy_team.size() + (BOSS_ESSENCE + 2 * floor_num if current_enemy.has_meta("boss") else 0))
```
`current_enemy` is set only in `try_start_battle` (`level.gd:800`). The `_boss_intro` / `start_battle` path is `await`ed, and `_end_run()` calls `get_tree().reload_current_scene()` — but before that, `_on_battle_ended(false)` at line 852 awaits `_end_run()`, which awaits `box.closed`. If the player quits to the hub (`H` action) or the scene reloads while the battle is resolving, `current_enemy` may be freed by `_clear_floor()` → `current_enemy.has_meta()` on a freed object throws.

Additionally `current_enemy` is never reset to `null` after the battle, so the stale node persists across floors.

**Fix:** add `if current_enemy == null or not is_instance_valid(current_enemy):` guard at the top of `_on_battle_ended`, and set `current_enemy = null` in `_end_battle()`.

### 1.3 `scripts/battle_system.gd:71` — division by zero / infinite recursion when `turn_order` is empty
```gdscript
current_turn_index = (current_turn_index + 1) % turn_order.size()
```
`turn_order.size()` is 0 if `player_team` and `enemy_team` are both empty → `% 0` → runtime error. `start_battle` never validates that `enemies` is non-empty, and `level.gd:818` does `enemies[0]` for the boss path — but `try_start_battle` accepts any Area2D, and `level.gd:620` (`_open_coffin` ambush) sets `enemies` from `_enemy_group()` which is never empty. Still, `start_battle` is a public API used by tests with arbitrary arrays.

Also `next_turn()` recurses on itself (line 75, 91, 98) — with a dead actor it recurses per dead actor; with many dead enemies this is unbounded recursion.

**Fix:** guard at the top of `next_turn()`:
```gdscript
if turn_order.is_empty():
    is_battle_active = false
    battle_ended.emit(false)
    return
```
and convert the self-recursion into a `while` loop.

---

## 2. HIGH (should fix)

### 2.1 `scripts/battle_system.gd:116-133` — `player_attack` / `player_use_skill` index without validation
```gdscript
var target = enemy_team[target_index]
```
`target_index` comes from `_pick_target` (safe) but also from `first_alive_enemy()` which can return **-1** when all enemies are dead (`battle_system.gd:110-114`). `_on_skill_selected` (line 355) calls `player_use_skill(index, first_alive_enemy())` for heal/self skills — if the battle just ended, `first_alive_enemy()` returns -1 → `enemy_team[-1]` → out-of-bounds error.

**Fix:** in `player_attack` and `player_use_skill`, add `if target_index < 0 or target_index >= enemy_team.size(): return`.

### 2.2 `scripts/character_data.gd:186` — `equip()` crashes on a `CONSUMABLE`
```gdscript
var slot = {ItemData.ItemType.WEAPON: "weapon", ...}[item.type]
```
The dictionary has no `CONSUMABLE` key → the lookup returns `null` → `equipment[null]` → invalid key error. `inventory_menu.gd:66-74` correctly routes consumables to `use_item`, so the UI path is safe, but `equip()` is a public method on `CharacterData` with no precondition check. `sim_balance.gd:145` calls `p.equip(it)` guarded by type, so tests don't hit it.

**Fix:** `if item.type == ItemData.ItemType.CONSUMABLE: return null` at the top of `equip()`.

### 2.3 `scripts/save_game.gd:38-41` — saved stats are trusted blindly
```gdscript
for s in STATS:
    if d.has(s):
        c.set(s, int(d[s]))
```
`hp` can be set to a negative or >`max_hp` value, and `max_hp`/`max_mp` can be zero or negative. `max_hp = 0` later causes `int(max_hp * 0.1)` in `tick_statuses` and division in `Bar.set_value` (`maxi(1, m)` guards the bar, but not `character_data`). A hand-edited or truncated save can make the player immortal or one-shot.

**Fix:** clamp after loading: `c.hp = clampi(c.hp, 0, c.max_hp)`, `c.max_hp = maxi(1, c.max_hp)`, same for `max_mp`/`mp`.

### 2.4 `scripts/level.gd:127-144` — class-select button closure captures `data` from the loop
```gdscript
for c in [...]:
    var data = CharacterData.create_for_class(c)
    ...
    b.pressed.connect(func():
        meta.apply_to_run(data)
```
This is correct in GDScript (each iteration creates a new `data`), so no bug here — **but** `b.pressed.connect(func(): ...)` is connected *before* `card.add_child(b)`, and the lambda captures `layer`, `menu`, `data` by value. `layer.queue_free()` frees the CanvasLayer, then `add_child(menu)` adds the PactMenu to `self` — the PactMenu is added to the *Level*, not the freed layer, so it survives. Correct, but fragile and hard to read.

**Nit (MINOR):** move the lambda body into a named method `_on_class_selected(data, layer)` for readability.

### 2.5 `scripts/level.gd:797-819` — `try_start_battle` is re-entrant
```gdscript
func try_start_battle(enemy_node: Area2D):
    if busy:
        return
```
`busy` is set to `true` at line 808, but there are `await`s before that (`await lunge.finished` at 816, `await _boss_intro(...)` at 818). Between the call and `busy = true` there is **no await**, so the guard is correct — **except** `await lunge.finished` and `await _boss_intro()` happen *after* `busy = true`. That part is fine.

However, `player.process_mode = Node.PROCESS_MODE_DISABLED` (line 809) is set, but `busy` is only reset in `_end_battle()`. If `battle_system.start_battle` is never reached (e.g. `enemies` is empty → `enemies[0]` at line 818 throws for a boss with no enemies), the game is stuck with `busy = true` forever.

**Fix:** wrap the boss-intro/start in a guard that restores `busy` on failure.

### 2.6 `scripts/sfx.gd:11-17` — unbounded AudioStreamPlayer node churn
```gdscript
var p = AudioStreamPlayer.new()
...
node.add_child(p)
```
Every footstep creates a node under the player; the node is freed on `finished`. With 3 step sounds at ~3.3/s this is ~10 nodes/s — acceptable, but the same node (`self` = level) is used for one-shots and the node is **never removed if the sound fails to load** (`load()` of a missing file returns `null` → `p.stream = null` → `p.play()` errors and `finished` never fires → the node leaks forever).

Note the `FILES` map mixes extensions: `"sword": "sword_hit.mp3"` and `"hit": "impactMetal_medium_000"` — the code appends `.ogg` only when there's no `.` in the name. `FILES[key]` will throw a KeyError for any key not in the map. All current call sites use valid keys, but there's no guard.

**Fix:** use `if not FILES.has(key): return` and `if p.stream == null: p.queue_free(); return`.

### 2.7 `scripts/music.gd:26` — `load()` of a music track returns `null` for a missing file
```gdscript
var s: AudioStreamMP3 = load("res://assets/audio/music/%s.mp3" % key)
s.loop = true
```
If `key` is invalid (`"title"`, `"explore"`, `"deep"` exist, so this is fine today) the null deref crashes. Also `s.loop = true` mutates the **shared cached resource** — every `load()` of the same file returns the same `AudioStreamMP3` instance, so this is benign here but is a code smell.

**Fix:** `if s == null: return` and use `s.loop_mode = AudioStreamMP3.LOOP_FORWARD` on a `duplicate()`.

### 2.8 `scripts/level.gd:858` — `_end_run` reads `c.level` after the character may be gone
```gdscript
var c = player.character_data
...
"Has caído en el piso %d.\nNivel %d..." % [floor_num, c.level, c.relics.size(), ...]
```
If `player.character_data` is `null` (possible: `level.gd:62` only assigns it when `saved[0] != null`, and `_show_class_select` defers assignment until the player picks a class), `c.level` throws. `_end_run` is only reachable via `_on_battle_ended(false)` which requires a battle, which requires a character — so this is low-probability. **MEDIUM** severity, but worth a null guard since `player.character_data` is typed `CharacterData` (nullable) and `level.gd:640` `_drink_well` already dereferences it without a check.

---

## 3. MEDIUM (consider fixing)

### 3.1 `scripts/level.gd:826-847` — `_end_run()` clears `player_inventory.items` but not equipped gear
```gdscript
player_inventory.items.clear()
SaveGame.save(null, player_inventory, 0, max_floor, quests, 0, meta)
```
Equipment is stored on the CharacterData, which is dropped by saving `null` — so equipment is lost. But `relics`/`skills` are also on the character, so that's consistent. **However** the gold is kept, and the comment on line 854 says "se conservan el oro y la meta" — correct. No bug; **the real issue** is `player_inventory.items.clear()` happens *before* `SaveGame.save`, so items are gone, but `_end_run` is `await`ed after `_open_dialog` — if the player closes the dialog with Esc mid-way the run never ends. `DialogBox` with `closable=true` (default) allows Esc → `_finish(Callable())` → `closed` emitted → `await box.closed` resumes → `_end_run` continues. OK.

### 3.2 `scripts/battle_system.gd:242-261` — `check_battle_end` revives the player inside a loop with a `break`
```gdscript
for p in player_team:
    if p.hp <= 0 and p.revive_ready:
        p.revive_ready = false
        p.hp = maxi(1, p.max_hp / 2)
        ...
    if p.hp > 0:
        all_dead = false
        break
```
With a single player this works. But the revive happens *before* the `break` check — correct. The subtlety: `ui.float_text` and `ui.add_log` are called but `ui` could be null if `_ready` failed (it pushes an error but doesn't return). `check_battle_end` is called from `next_turn` which is called from `start_battle` — `ui` is set in `_ready`, so it's non-null in practice. **MEDIUM**: `ui` is typed `Control` (nullable) and is dereferenced unguarded at lines 85, 94, 143, 218, 250-251, etc., while `start_battle` itself checks `if ui:` at line 51. Inconsistent guarding.

### 3.3 `scripts/battle_system.gd:194-206` — `incoming_count()` / `incoming_damage()` recompute intents on every call
`intent_info()` is called O(enemies) times per `update_stats()`, and `update_stats()` is called on every turn. With ≤5 enemies this is negligible. **MINOR** — but `battle_ui.gd:244` calls `system.incoming_damage()` **and** `system.incoming_count()`, each iterating the team and calling `intent_info` again → 4× redundant work per update. Cheap, but easy to memoize.

### 3.4 `scripts/character_data.gd:149-159` — `tick_statuses` mutates `statuses` while iterating `statuses.keys()`
```gdscript
for s in statuses.keys():
    statuses[s] -= 1
    if statuses[s] <= 0:
        statuses.erase(s)
```
`statuses.keys()` returns a **new Array** snapshot in Godot 4, so erasing during iteration is safe. **No bug.** However `tick_statuses` applies bleed *then* decrements all statuses — so a status applied this turn ticks down immediately. That's the intended "duration in turns" semantics. Fine.

### 3.5 `scripts/character_data.gd:149` — bleed can kill the player, but the caller ignores it
`battle_system.gd:83-89`: `actor.tick_statuses()` then `if actor.hp <= 0: next_turn()`. The bleed damage is applied and the actor dies — but `check_battle_end()` is called at line 87 *before* the `hp <= 0` check, and `check_battle_end` revives if `revive_ready`. Correct ordering.

### 3.6 `scripts/level.gd:390` — integer division in `_battle_backdrop`
```gdscript
var theme = ((floor_num - 1) / 5) % BACKDROPS.size() if floor_num > 0 else randi() % BACKDROPS.size()
```
`floor_num` is `int`, so `/` is integer division in GDScript — this is **correct** here (Godot 4 keeps `/` as integer division for ints). Same at line 361 (`_crypt`) and 414. Consistent and intentional. **No bug** — worth noting because the mixed use of `/` and `/` for floats elsewhere (e.g. `character_data.gd:152` `max_hp * 0.1`) is a readability trap.

### 3.7 `scripts/level.gd:414` — `FLOORS[((floor_num - 1) / 5) % FLOORS.size()]` when `floor_num == 0`
Guarded by `if tower else FLOORS[0]` — `tower = floor_num > 0`. Safe.

### 3.8 `scripts/level.gd:346` — `int(w / 16) - 4` can go negative for small floors
```gdscript
var r = Rect2(Vector2(randi_range(3, int(w / 16) - 4), ...) * 16, size)
```
`w = floor_size.x = 640` for towers → `int(640/16) - 4 = 36`. Safe. Hub (`320`) doesn't call `_build_walls`. Safe.

### 3.9 `scripts/level.gd:379-385` — `_free_pos` may return a position outside the area
```gdscript
for i in 60:
    p = Vector2(randf_range(...), randf_range(...))
    if <cond>: break
return p
```
If no iteration satisfies the condition, it returns the **last random point**, which may be inside a wall or too close to the player. The `test_floor_reachability.gd` test covers this (flood-fill asserts 0 unreachable) and passes, so in practice 60 tries suffice. **MEDIUM**: make the fallback explicit — `return area.get_center()` or retry more.

### 3.10 `scripts/level.gd:431` — the stairs area is created with a lambda that ignores the node
```gdscript
_make_area(45, 16, Vector2(160, 198), func(_a): _go_floor(maxi(1, run_floor))).get_child(0).visible = false
```
The `.get_child(0).visible = false` hides the sprite, but the comment says "las escaleras ya están en el fondo" (the hub background already has stairs drawn). This creates a **hidden but functional** interaction area at the hub's bottom that teleports the player to the tower — with no visual affordance. The `test_npc_collision.gd` test confirms it works ("escaleras del hub llevan a piso max"). Intentional but confusing; the Area2D has a `CollisionShape2D` the player can walk into with no indication.

### 3.11 `scripts/player.gd:19` — `load("res://assets/walk.gdshader")` on every player instantiation
The shader is loaded per player/enemy (`enemy_ai.gd:33` also does this per enemy). Godot caches `load()` results by path, so this is a dictionary lookup — **negligible**. But `sprite.material = ShaderMaterial.new()` per enemy means each enemy gets its **own** shader material instance (needed, since `walk`/`phase` are per-sprite uniforms). Correct as-is.

### 3.12 `scripts/player.gd:79-91` — `_dust()` adds children to `get_parent()` and never removes them on scene change
`ColorRect` nodes are added to the Level and freed by `tw.chain().tween_callback(d.queue_free)`. If the scene is reloaded mid-tween, `queue_free` on a freed node is a no-op. Fine.

### 3.13 `scripts/level.gd:288-290` — `battle_system.gold_mult` applied twice
```gdscript
var gold_drop = int(randi_range(5, 20) * (1.5 if pc.has_relic("bolsa") else 1.0) * gold_mult)
```
`gold_mult` = `meta.gold_mult() * Pacts.gold_mult(pacts)` (`level.gd:737`). And `Pacts.gold_mult` already applies the "pobreza" half. Consistent — no double-application. **No bug.**

### 3.14 `scripts/quest_log.gd:19-20` — `add(kind)` with an unknown kind adds a new counter key
```gdscript
func add(kind: String, n: int = 1) -> void:
    counters[kind] += n
```
`counters` is initialized with `kill`/`boss`/`floor`. `level.gd:832` calls `quests.add("kill", ...)` and `:838` `quests.add("boss")` — valid. But `QuestLog.from_dict` only restores the three known keys, so an unknown kind would be dropped on save/load. No current call path. **MINOR.**

### 3.15 `scripts/level.gd:771` — quest counters are overwritten, not accumulated
```gdscript
quests.counters["floor"] = max_floor
```
The comment in `quest_log.gd:3` says "contadores acumulados (no empiezan al aceptar)". But `floor` is *assigned* rather than incremented — which is actually correct semantics for "piso alcanzado" (highest floor reached). Consistent. **No bug.**

### 3.16 `scripts/dialogues.gd:66` — `hp_below_pct` compares against `s.max_hp` which may be 0
`s.hp * 100 < s.max_hp * when[k]` — if `max_hp` is 0, `0 < 0` is false. Safe (no division).

### 3.17 `scripts/altar_menu.gd:53` — `list.get_child(i).disabled = false` is a no-op with a misleading comment
```gdscript
list.get_child(i).disabled = false # sin deshabilitar: el foco no se pierde al comprar
```
The comment says "without disabling" but the code explicitly sets `disabled = false`. It's a **redundant** assignment (buttons are never disabled) — the comment explains why it *isn't* set to true. Confusing but harmless. **MINOR**: delete the line or fix the comment.

### 3.18 `scripts/inventory.gd:23` — `has_item` is dead code
Never called anywhere in `scripts/` or `tests/`. **MINOR**: remove.

### 3.19 `scripts/character_data.gd:161` — `status_text()` is dead code
Never called. **MINOR**: remove.

### 3.20 `scripts/controls.gd:10-12` — the global `node_added` hook never gets disconnected
```gdscript
tree.node_added.connect(func(n: Node):
    if n is BaseButton:
        n.pressed.connect(func(): Sfx.play(tree.root, "click", -6.0)))
```
`Controls.setup()` guards with `_click_hooked`, so it connects once per process — fine. But `Sfx.play(tree.root, ...)` adds an `AudioStreamPlayer` to the **root** node on every button press; the player is freed on `finished`. Fine.

However: the lambda captures `tree`, keeping the `SceneTree` alive — it's a static lambda connected to a tree signal, so it lives as long as the tree. Fine.

### 3.21 `scripts/level.gd:722-724` — `_note` leaks a timer per call
```gdscript
get_tree().create_timer(3.0).timeout.connect(func():
    if msg.text == text:
        msg.text = "")
```
Each `_note` creates a `SceneTreeTimer`. With frequent notes (every coffin, every essence gain) these accumulate for 3s. Negligible, but the `msg.text == text` guard means an older timer can clear a *newer* message with identical text. **MINOR**.

### 3.22 `scripts/item_data.gd:31-36` — `icon()` re-tints pixel-by-pixel at runtime
```gdscript
for y in img.get_height():
    for x in img.get_width():
        img.set_pixel(x, y, img.get_pixel(x, y) * TINTS[id])
```
16×16 = 256 `get_pixel`/`set_pixel` calls, once per tinted item, cached in `_icons`. **Negligible** — the cache makes it a one-time cost. But `load(...).get_image()` on a **CompressedTexture2D** returns a compressed image; `set_pixel` on a compressed image fails silently in Godot 4. The `.import` file shows `compress/mode=0` (lossless) — but `textures/vram_compression/import_s3tc_bptc=true` in `project.godot` is the *runtime* VRAM compression setting. With `compress/mode=0` the imported texture is stored lossless (VRAM-uncompressed for 2D), so `get_image()` returns an uncompressed image and `set_pixel` works. `test_content.gd:35` asserts `it.icon() != null` for every item, so this path is verified working. **No bug**, but fragile if someone switches a tile to VRAM compression.

---

## 4. MINOR (nice to have)

### 4.1 `scripts/battle_ui.gd:72` — button style keyed on the enemy's name hash
```gdscript
var v = "abc"[key.md5_buffer()[0] % 3]
```
`md5_buffer()[0]` is a signed byte in Godot (`int8` in the PackedByteArray → but `[]` returns int 0-255 in GDScript). `PackedByteArray[0]` returns an int 0-255, so `% 3` is non-negative. Fine. The style is recomputed and a new `Theme` allocated on **every** battle (`setup_battle` → `_apply_button_style`), loading 3 PNGs each time. **MEDIUM** → move to a static cache.

### 4.2 `scripts/battle_ui.gd:139-147` — `_clear_row` + `_add_icon` churn
`update_stats()` calls `_clear_row` (queue_free) then re-adds children every turn — `queue_free` is deferred, so the row briefly contains both old and new children, and `get_child_count()` in `test_targeting.gd:38` (`assert(bs.ui.incoming_row.get_child_count() == 0)`) depends on the `await process_frame` timing. **Fragile test dependency.** Better: hide/reuse children or `remove_child` + `queue_free`.

### 4.3 `scripts/battle_ui.gd:207` — `get_meta("floats", 0)` / `set_meta` used as a counter
Works, but `meta` on a `Sprite2D` is a `Variant` store. Fine, though `spr.get_meta("floats", 1) - 1` at line 216 mixes the default `1` with the `0` default at 207 — inconsistent defaults. **MINOR**: unify to `0`.

### 4.4 `scripts/level.gd:604-609` — `_make_event` uses an array as a closure cell
```gdscript
var holder = []
...
var a = _make_area(0, 24, pos, func(): handler.call(holder[0]), hint, tex)
holder.append(a)
```
Works (the array is filled before the callback fires), but it's a hand-rolled late-binding closure. GDScript lambdas capture by value at creation, so this is the idiomatic workaround. **MINOR**: add a comment explaining why.

### 4.5 `scripts/level.gd:797` — `try_start_battle` has a 3-parameter mismatch with `_make_area`
`_make_area(tile, size, pos, on_enter, hint, tex)` expects `on_enter: Callable` taking the area; `try_start_battle(enemy_node)` matches. But `_make_area` at line 264 connects `on_enter.call(a)` for non-hint areas and `nearby = on_enter` (a zero-arg call) for hint areas. Two different calling conventions for the same parameter — a latent bug if a hint area is ever wired to `try_start_battle`. It isn't today (`try_start_battle` is always called with `hint == ""`). **MINOR**: document the dual convention or split into two methods.

### 4.6 `scripts/battle_system.gd:182` — `plan_intent` uses `randf() < 0.4` per plan, so a 0-MP skill is planned then fails
```gdscript
e.intent_skill = usable.pick_random() if not usable.is_empty() and randf() < (...) else null
```
`usable` filters by `sk.mp_cost <= e.mp`, so the planned skill is always affordable *at plan time*. But `enemy_turn` re-checks `enemy.use_mp(skill.mp_cost)` and falls back to a basic attack if the MP ran out (e.g. the player drained MP — but nothing drains enemy MP). Defensive and correct.

**However**: the intent shown is the skill, and if MP ran out the enemy performs a *basic attack* instead — the displayed intent would lie. `test_intents.gd` asserts "la intención que se muestra es lo que el enemigo hace luego", and it passes because MP doesn't change. **MEDIUM**: if `intent_skill` is set but MP is insufficient at execution time, the display breaks its contract. Currently unreachable.

### 4.7 `scripts/battle_system.gd:274` — boss EXP doubles the reward
```gdscript
exp_gained += (10 + 15 * e.level) * (2 if e.is_boss else 1)
```
Intentional.

### 4.8 `scripts/level.gd:104` — `player.process_mode = Node.PROCESS_MODE_DISABLED` used to freeze the player
The player's `_physics_process` stops, but `_process` on other nodes (EnemyAI `_physics_process` checks `level.busy`) still runs. Consistent.

### 4.9 `tests/sim_balance.gd:30` — `_act.call_deferred()` inside a `turn_changed` signal handler
Standard pattern for avoiding re-entrancy. Fine.

### 4.10 `tests/*.gd` — `assert()` is stripped in release builds
All tests use `assert()` which Godot **ignores in release mode**. If the tests are ever run with a release template, they silently pass. **MINOR**: use an explicit `fail()` helper (as `test_flow.gd` does) or check `OS.is_debug_build()`.

### 4.11 `tests/test_flow.gd:56` — brittle scene-tree introspection
```gdscript
lvl.get_children().filter(func(n): return n is CanvasLayer and n != lvl.battle_system and n.layer == 5)
```
Hard-coded layer numbers and child ordering. Fragile but works.

### 4.12 `scripts/shadow.gd:26` — `spr.get_node("Shadow")` will throw if the node is missing
```gdscript
static func fit(spr: Sprite2D) -> void:
    var s = spr.get_node("Shadow")
```
`Shadow.fit` is called from `player.gd:26` (after `Shadow.attach`, so it exists) and from `Shadow.attach` itself. But if any code path calls `Shadow.fit` on a sprite without a Shadow child, it throws. **MINOR**: use `get_node_or_null` and return early.

### 4.13 `scripts/battle_ui.gd:206` — `spr.texture.get_height()` assumes a non-null texture
`sprites` are built from `c.texture()` which always returns a texture. Safe today.

### 4.14 `scripts/level.gd:285` — `_clear_floor` iterates the global `"floor_obj"` group
```gdscript
for n in get_tree().get_nodes_in_group("floor_obj"):
    n.queue_free()
```
This frees floor objects from **any** scene in the tree, not just this level's. Currently only the Level registers nodes in that group. **MINOR**: use a locally-tracked array instead of a global group, or scope the search to `self`.

### 4.15 `scripts/meta.gd:29` — `cost()` uses `u.cost` (dynamic dictionary access)
`u.cost` on a `Dictionary` works via `Dictionary.cost`? No — `u` is a `Dictionary`, and `u.cost` accesses the key `"cost"`. GDScript allows `dict.key` syntax for dictionary access. Works but inconsistent with `u.get("stats", {})` used elsewhere (`upgrades.gd:50`). **MINOR**: prefer `u["cost"]` for clarity.

### 4.16 `scripts/meta.gd:57` — "herencia" relic is applied **randomly** without player choice
```gdscript
var r = Upgrades.relic_offers(c, 1)
if not r.is_empty():
    Upgrades.apply_relic(c, r[0])
```
`relic_offers` shuffles, so the player gets a random relic with no choice. `test_meta.gd` acknowledges this ("la reliquia es aleatoria"). **Design note**, not a bug — but it's inconsistent with the meta-upgrade being a *player* choice.

### 4.17 `scripts/battle_system.gd:366-384` — `generate_drops()` accesses `enemy_team[0]` without a bounds check
If `enemy_team` is empty (possible per §1.3), this throws. **HIGH** if reachable — folded into 1.3.

### 4.18 `scripts/level.gd:433` — `var w = floor_size.x` / `h` computed but `w` used only for the boss rect
Minor unused-ish variable usage. Not a bug.

---

## Resumen por área

| Área | Estado |
|---|---|
| **Persistencia (`save_game.gd`)** | ⚠️ **Más débil del código.** Validación de entrada incompleta; se confía en el JSON. Sin candado ni checksum, pero es un juego local — aceptable si se valida bien. |
| **Combate (`battle_system.gd`)** | ⚠️ Índices sin validar (`target_index`, `enemy_team[0]`, `turn_order.size()`), recursión en `next_turn`, y `ui` dereferenciado de forma inconsistente. La lógica de intenciones es correcta y bien testeada. |
| **Nivel (`level.gd`)** | ⚠️ Es el archivo más grande (879 líneas) y mezcla 6 responsabilidades: generación de pisos, spawn, eventos, HUD, diálogos y flujo de run. Deuda de mantenibilidad alta. `current_enemy` sin invalidar. |
| **Datos (`character_data.gd`, `item_data.gd`, `upgrades.gd`, `pacts.gd`, `meta.gd`)** | ✅ **Código limpio.** Datos puros, sin estado global mutable salvo los caches estáticos de iconos. `equip()` necesita un guard de tipo. |
| **UI (`battle_ui.gd`, menús)** | ⚠️ Construcción programática de widgets en cada apertura (temas, listas); `queue_free` diferido hace frágil `test_targeting.gd`. Falta `ui` null-check consistente en `battle_system.gd`. |
| **Enemigos / jugador (`enemy_ai.gd`, `player.gd`)** | ✅ **Limpio.** La IA por ejes con deslizamiento es correcta; el shader de pasos funciona bien. Sin fugas de nodos. |
| **Tests** | ⚠️ Buena cobertura (~13 archivos, incluidas simulaciones de balance y flood-fill de alcanzabilidad). Pero usan `assert()` (se elimina en release) y dependen de la forma del árbol de escenas. |
| **Seguridad** | ✅ Sin superficies de ataque relevantes. No hay red, ni entrada de usuario, ni eval. La entrada de usuario (JSON del guardado) es la única fronteira y está parcialmente validada — ver 1.1 y 2.3. |
| **Rendimiento** | ✅ **Sin problemas reales.** Los bucles píxel-a-píxel están cacheados; los nodos de audio se liberan; los `load()` de Godot están cacheados por ruta. Lo único notable es el `Theme` recreado por combate (`battle_ui.gd:71`) y la re-calculación redundante de `incoming_damage()`/`incoming_count()`. |

**Prioridad de arreglo:** 1.1 → 2.1 → 1.3 → 2.3 → 1.2 → 2.2. Los seis restantes son bajas prioritized.