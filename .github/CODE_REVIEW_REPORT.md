# Code Review Report: VampireCityRPG

Generated: 2026-10-29 (nightly automated review, Claude Code)

Scope: `scripts/battle_system.gd`, `scripts/battle_ui.gd`, `scripts/controls.gd`, `scripts/bar.gd`, `scripts/level.gd`, `scripts/save_game.gd`.
All findings below were verified line-by-line against the source in this branch.

---

## 1. CRITICAL (must fix)

### 1.1 `scripts/battle_system.gd:93-99` — a stunned enemy leaves `is_player_turn == true`, letting the player act out of turn

`next_turn()` sets `is_player_turn` at line 101, but the stunned branch returns at line 99 **before** reaching it. `is_player_turn` therefore keeps its previous value (`true`, set on the player's turn) for the whole enemy "turn".

The attack menu stays on screen and `player_attack()` (line 116-118) only checks `is_player_turn` / `is_battle_active` — so the player can attack during the enemy's turn. That attack itself calls `next_turn()` again, spawning a **second, parallel turn chain** and corrupting turn order and enemy intent.

**Fix:** set `is_player_turn = not current_actor.is_enemy` *before* the stunned branch:

```gdscript
is_player_turn = not current_actor.is_enemy
if stunned:
    ...
    next_turn()
    return
```

### 1.2 `scripts/battle_system.gd:71-76` — unbounded recursion in `next_turn()` skips the battle-end check

When the actor at `current_turn_index` is dead, the function calls `next_turn()` recursively at line 75 **before** `check_battle_end()` (line 87) is ever reached. There is no iteration guard, and the recursion depth equals the number of consecutive dead actors.

If every actor in `turn_order` is dead while `is_battle_active` is still `true` (e.g. the player dies to a DoT in the same frame the last enemy dies, or a stale `turn_order` after `start_battle` with a dead enemy), this recurses until stack overflow — hang with no defeat screen.

**Fix:** replace the recursion with a bounded loop and check the battle end *before* skipping dead actors:

```gdscript
for _i in turn_order.size():
    current_turn_index = (current_turn_index + 1) % turn_order.size()
    ...
    if actor.hp > 0: break
else:
    check_battle_end()
    return
```

### 1.3 `scripts/save_game.gd:19-20` — `FileAccess.open()` result is never checked

```gdscript
var f = FileAccess.open(PATH, FileAccess.WRITE)
f.store_string(JSON.stringify(d))
```

`open()` returns `null` on failure (read-only `user://`, disk full, permission error). The next line then raises *"Attempt to call function 'store_string' on a null instance"*, crashing the game at every save point — the run is lost with no way to recover. This is the only persistence path in the game.

**Fix:**

```gdscript
var f := FileAccess.open(PATH, FileAccess.WRITE)
if f == null:
    push_error("SaveGame: no se pudo abrir %s (err %d)" % [PATH, FileAccess.get_open_error()])
    return
f.store_string(JSON.stringify(d))
f.close()
```

---

## 2. HIGH (should fix)

### 2.1 `scripts/battle_ui.gd:87-90` — unchecked index access on empty teams

```gdscript
player_char = player_team_ref[0]
enemy_team = enemy_team_ref
_apply_button_style(enemy_team_ref[0].character_name)
```

`setup_battle` is called from `BattleSystem.start_battle` with whatever the caller passes. An empty `enemies` array (or an empty player team) → immediate `IndexError` on the first frame of the battle.

**Fix:** guard with `if player_team_ref.is_empty() or enemy_team_ref.is_empty(): push_error(...); return`.

### 2.2 `scripts/battle_system.gd:311-319` + `:116-121` — target index `-1` wraps to the last enemy

`_pick_target()` calls `on_pick.call(first_alive_enemy())` when `alive.size() <= 1`; `first_alive_enemy()` returns `-1` (line 114) when **no** enemy is alive. That `-1` flows into `player_attack()` → `enemy_team[target_index]` (line 121), and in GDScript a negative index is legal and silently targets the **last** enemy — a corpse. The player "attacks" a dead enemy and the turn is consumed.

**Fix:** in `_pick_target`, bail out when `alive.is_empty()`; in `player_attack` / `player_use_skill`, reject the index with `if target_index < 0 or target_index >= enemy_team.size(): return`.

### 2.3 `scripts/battle_system.gd:352-357` — `skill_index` and `target_index` are not validated

`_on_skill_selected(index)` does `player_team[0].skills[index]` (line 353) with the index taken straight from the UI signal, and `_on_skill_selected` also passes `first_alive_enemy()` (possibly `-1`) as the target for heal / on_self skills (line 355). Any desync between the UI's skill list and `player_team[0].skills` (list rebuilt between menu open and click, or a save/load in between) → out-of-range crash.

**Fix:** bounds-check both indices at the top of `player_use_skill` and in `_on_skill_selected`.

### 2.4 `scripts/battle_system.gd:328` vs `:337-347` — the "ayuno" pact is only checked when opening the item menu

`_on_item_pressed()` (line 328) blocks opening the item menu when the player has the `ayuno` pact. `_on_item_selected()` (line 337) — the handler that actually consumes the item — does **not** re-check the pact, and removes the item unconditionally (line 347). Any path that reaches `show_item_menu` without going through `_on_item_pressed` (or a pact applied while the menu is open) consumes an item the player is not allowed to use.

**Fix:** check the pact in `_on_item_selected` as well, and only remove the item if the effect was actually applied.

### 2.5 `scripts/save_game.gd:23-56` — loaded save data is never validated

`load_game()` applies `int(d[s])` directly to `level`, `hp`, `max_hp`, `experience`, `experience_to_next_level`, etc. (lines 39-41) with no range checks, and `CharacterData.create_for_class(int(d["class"]))` (line 38) trusts the stored class index. The save file lives in `user://` and is user-writable, so a corrupted or hand-edited save can set `level` negative, `hp` far above `max_hp`, or desync `experience_to_next_level` from the level curve (it is listed in `STATS` and restored verbatim).

**Fix:** clamp each stat on load (`c.hp = clampi(c.hp, 0, c.max_hp)`, `c.level = maxi(1, c.level)`), validate the class index against the known `ClassType` values, and recompute `experience_to_next_level` from the level instead of restoring it.

---

## 3. MEDIUM (consider fixing)

### 3.1 `scripts/battle_system.gd:337-347` — item is removed from the inventory even if it had no effect

`use_item()` (`scripts/character_data.gd:196-198`) clamps healing to `max_hp` and returns nothing, so a potion used at full HP heals 0 — but `player_inventory.remove_item(item)` (line 347) still runs. The player loses the item for no effect. `player_inventory` is also not null-checked here, unlike in `_on_item_pressed` (line 331).

**Fix:** have `use_item()` report whether it applied anything, and only remove the item when it did. Guard `player_inventory != null` before `remove_item`.

### 3.2 `scripts/battle_system.gd:380` — boss drop checks only `enemy_team[0]`

```gdscript
if enemy_team[0].is_boss:
```

If the boss is not at index 0 (a mixed group), the guaranteed equipment drop never happens; if `enemy_team` is empty, this is an index error.

**Fix:** `if enemy_team.any(func(e): return e.is_boss):`

### 3.3 `scripts/battle_system.gd` — `ui` is dereferenced unguarded in ~10 places

`_ready()` explicitly handles a missing `$BattleUI` with `push_error`, but the action handlers dereference `ui` unconditionally (e.g. lines 85, 94, 125, 323, 335). A missing or misnamed node in the scene turns a recoverable config error into a crash mid-battle.

**Fix:** null-check `ui` once in `_ready` and early-return in each action (`if not ui: return`).

### 3.4 `scripts/level.gd:379-385` — `_free_pos()` may return a position inside a wall

The loop tries 60 random points and `break`s on success, but if **no** point satisfies the constraints it returns the last random candidate — which can be inside a `blocked` rect, i.e. an enemy spawns embedded in a wall or pillar and is unreachable. The same applies at line 869, where `Rect2.intersection` may return a degenerate rect and `randf_range(area.position.x, area.end.x)` samples inverted bounds.

**Fix:** track success with a flag and fall back to a known-good position (e.g. `start_pos` or the area centre) when the loop fails; guard `area.size` before sampling.

### 3.5 `scripts/save_game.gd:11` — a `null` meta silently discards progression

`"meta": (meta if meta else Meta.new()).to_dict()` writes a fresh empty meta if a caller forgets the argument — essence, streak and unlocks are wiped with no warning.

**Fix:** make the meta parameter required, or push a warning when it is null.

### 3.6 `scripts/save_game.gd` / `scripts/level.gd` — untyped array as a return contract

`load_game()` returns a 7-element `Array` accessed positionally (`saved[1]`…`saved[6]`). A change in the return order or length silently assigns e.g. a `QuestLog` to an `int` variable → runtime type error. There is also no `version` field in the save format, so future schema changes have no migration hook.

**Fix:** return a small typed object (or a `Dictionary` with named keys), and add a `"version": N` field with a migration step in `load_game()`.

### 3.7 `scripts/level.gd:162` and `:612-616` — the `nearby` callable is a single global slot

`nearby` is overwritten by whichever NPC area was entered last, and `_remove_obj` (line 616) clears it even if another NPC is still in range. Two overlapping interaction areas leave the player talking to the wrong NPC.

**Fix:** keep a `Dictionary`/array of active interaction candidates and pick the nearest.

### 3.8 `scripts/level.gd:246-262` — the `chosen` signal is shared and never reset

`_choose()` awaits `level.chosen`; the signal is a member of the level and is not cleared between uses, so a late or stale emission could satisfy a later `await chosen`.

**Fix:** use a one-shot local signal per dialog instead of a shared member.

### 3.9 `scripts/battle_ui.gd:156-161` and `:138-140` — `queue_free()` leaves stale nodes visible for one frame

`_build_stage()` calls `queue_free()` on the old children (deferred) and immediately adds new ones, so both sets render for one frame. The same applies in `_clear_row`, which is called immediately before re-adding icons in `update_stats()`.

**Fix:** `remove_child()` + `queue_free()`, or defer the rebuild by one frame.

### 3.10 `scripts/battle_ui.gd:276-279`, `:302` — unguarded index access on target and icon lists

`show_target_menu` calls `_highlight(targets[0])` with no empty check, and line 302 does `Icons.skill_icons(sk)[0]` on a possibly empty array.

**Fix:** guard both with `is_empty()` checks.

### 3.11 `scripts/controls.gd:10-12` — the click-sound hook misses pre-existing buttons

`tree.node_added` is connected once per process and never disconnected; the lambda captures `tree`, keeping it alive. Buttons that existed **before** `Controls.setup()` runs are never hooked, so the click SFX is inconsistent.

**Fix:** iterate the existing tree as well (`tree.root.find_children("*", "BaseButton", true, false)`), and disconnect the hook when the level is torn down.

### 3.12 `scripts/battle_ui.gd:186-194` and `:282-287` — two tweens write `modulate` on the same node

`flash()` tweens `modulate` to `Color.WHITE` (alpha 1), which fights the death-fade tween in `update_stats()` that drives `modulate:a → 0`. `_highlight()` also writes `spr.modulate` wholesale, stomping the red damage flash.

**Fix:** tween a dedicated channel (`self_modulate`) or scale for the flash instead of touching alpha.

---

## 4. MINOR (nice to have)

- **`scripts/bar.gd:17-24`** — `set_value()` clamps the *fill* but not the label, so the text can render `-3/10` if a caller over-damages.
- **`scripts/bar.gd:33`** — `inner = Rect2(Vector2.ONE, size - Vector2(2,2))` yields a negative-size rect if the bar is smaller than 2×2 px.
- **`scripts/bar.gd:46`** — `get_theme_default_font()` can return `null` in a headless/test context; `font.get_string_size(...)` would then error.
- **`scripts/level.gd:713-717`** — `_spend_picks()` decrements `pending_picks` *before* the await and then formats the title with `c.level - c.pending_picks`, which is off by one against the level actually gained.
- **`scripts/level.gd:154-157`** — `_unhandled_input` never checks `event.is_echo()`, so holding a key can re-trigger actions inconsistently across platforms.
- **`scripts/level.gd:169-179`** — `busy` is only reset via the menu's `resumed`/`closed` signal; if the menu node is freed by any other path (scene change, `queue_free`), the game stays permanently busy.
- **`scripts/level.gd:868-870`** — `_open_stairs` samples `randf_range(area.position.x, area.end.x)` without checking that the intersected rect has a positive size.
- **`scripts/battle_system.gd:59-65`** — `turn_order.sort_custom()` on `speed` is not a stable sort; equal-speed actors can swap order between battles. Add a secondary key for determinism.
- **`scripts/battle_system.gd:35-57`** — `start_battle()` does not reset `player_team[0].intent_skill`, so the previous battle's intent leaks into the next one.
- **`scripts/battle_ui.gd:14-17`** — `sprites`, `hp_bars`, `status_rows` and `intent_rows` are keyed by `CharacterData` object identity; if two enemies ever share a `CharacterData` instance the second overwrites the first's bar. Key by index instead.
- **`scripts/controls.gd:19-29`** — `_add()` silently skips the binding if the action already exists in `project.godot`, so a mis-typed action name produces an unbound action with no warning.
- **`scripts/level.gd:44`** — `static var _glow_tex` is a cache shared across scene reloads; it is never invalidated, which is fine only because the gradient never changes. Worth a comment explaining why it is static.
- **Style** — `battle_system.gd` and `level.gd` mix Spanish and English in identifiers and comments (`is_battle_active` vs `enemigos`, `try_start_battle` vs `_open_coffin`). Worth settling on one convention.

---

**Overall:** the architecture is sound, but 1.1 (out-of-turn player actions during a stunned enemy turn) and 1.2 (unbounded recursion that can hang the battle with no defeat screen) are real logic bugs in the core battle loop and should be fixed before release, together with 1.3 (unchecked `FileAccess.open` on the game's only persistence path).
