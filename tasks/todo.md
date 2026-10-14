# Roadmap
- [x] Fase 0: limpiar y arreglar bugs (auto-battle, skills, run, walk anim, prints, main.gd)
- [x] Fase 1: inventario (I), equipo, objetos en combate, selección de clase, guardado (user://save.json)
- [x] Fase 2: hub (tienda/NPC) + torre de pisos con jefes, enemigos en mapa
- [ ] Fase 3: skills por clase, estados, diálogos/misiones, sonido, arte (Kenney / propio / IA), export móvil

## Plan Fase 2 (hecho)
1. [x] Estado de piso: `floor` en SaveGame (+ inventory/gold ya guardados). Dificultad = piso.
2. [x] Enemigos en mapa: 2-4 nodos `Area2D` (ColorRect rojo) por piso; tocar uno → combate con `difficulty = floor`; al ganar, desaparece. Quitar ENTER-para-combatir.
3. [x] Jefe por piso: `CharacterData.create_boss(floor)` (stats x2-3); escaleras `Area2D` aparecen al matar al jefe → `floor += 1`, regenerar piso.
4. [x] Hub (piso 0 / sótano, escena `hub.tscn` o modo en level.gd): NPC tienda (comprar/vender con `ItemData`, oro) + descanso (HP/MP full, coste oro). Botón/escalera para bajar a la torre.
5. [x] Guardar piso máximo; test headless de tienda + progresión de piso.

Decisión simple: un solo `level.gd` que genera el piso por código (hub si floor==0), sin escenas nuevas por piso.

## Plan Fase 3 (pendiente de confirmar)
Fase 3 es grande: la divido en 3a/3b/3c, una por sesión/commit.
**3a Combate (código puro):**
1. [x] Skills por clase: 4-5 por clase (Noble/Salvaje/Dhampir/Hemomante), desbloqueo por nivel, en `create_*` + `learn_skills_for_level()` en `level_up`.
2. [x] Estados: `statuses: Dictionary` en CharacterData (sangrado, aturdido, defensa↓, buff ATK) con turnos restantes; tick al inicio de turno en `battle_system`; `SkillData.status`/`status_turns`. Enemigos usan sus skills (hoy solo atacan normal).
**3b Contenido:**
3. [x] Diálogos + misiones: NPC en hub (`DialogBox` simple + `QuestData`: "mata N enemigos / derrota jefe del piso X", recompensa oro/objeto), progreso guardado en save.
**3c Pulido:**
4. Sonido: SFX/música con `AudioStreamPlayer` (necesito archivos: ¿Kenney/CC0?).
5. Arte: sprites (Kenney/propio/IA) reemplazando ColorRect.
6. Export Android/iOS (necesita plantillas de export + keystore, lo haces tú o te guío).

## Notas de sesión (2026-10-14)
- Fase 0 y 1 commiteadas (40180b2, f118afa). Godot 4.2.2 en /Applications/Godot.app.
- Se instaló el MCP godot (`@coding-solo/godot-mcp`, GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot). Tras reiniciar: verificar con `/mcp` y probar run_project + get_debug_output.
- Siguiente: Fase 2 (hub con tienda/descanso, torre por pisos, escaleras, jefe por piso, enemigos visibles en mapa, dificultad creciente).
- Cuidado: abrir el proyecto en Godot con "Importar", nunca "Nuevo proyecto" (sobrescribe project.godot). Si cambias class_name nuevas, correr `Godot --headless --path . --import`.
- Tests headless de apoyo: scripts SceneTree con `--script` (simulan combate, inventario, guardado).
