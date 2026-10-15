# Roadmap
- [x] Fase 0: limpiar y arreglar bugs (auto-battle, skills, run, walk anim, prints, main.gd)
- [x] Fase 1: inventario (I), equipo, objetos en combate, selección de clase, guardado (user://save.json)
- [x] Fase 2: hub (tienda/NPC) + torre de pisos con jefes, enemigos en mapa
- [x] Fase 3 (export móvil descartado; objetivo PC/Mac): skills por clase, estados, diálogos/misiones, sonido, arte (Kenney / propio / IA), export móvil

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
4. [x] Sonido: SFX/música con `AudioStreamPlayer` (necesito archivos: ¿Kenney/CC0?).
5. [x] Arte: sprites (Kenney/propio/IA) reemplazando ColorRect.
6. [descartado] Export móvil: el objetivo es PC y Mac. Pendiente: export de escritorio (plantillas de export + `export_presets.cfg`; en Mac, firma/notarización si se distribuye).

## Plan pulido visual (A y B hechos; C: arte propio, iconos y luz hechos; resto pendiente)
Problemas vistos en captura: texto = fuente vectorial por defecto rasterizada a 320x180 (borroso, desbordado, cortado en tienda/HUD); NPCs sin colisión (el jugador los pisa); paneles de menú semitransparentes (se ve el mapa detrás).
A. Texto y UI: fuente pixel CC0 (Kenney Fonts) como tema global a tamaños enteros (8/16); rehacer layouts de HUD, tienda, inventario, diálogo y combate; fondo opaco en menús; (opcional) tema de paneles/botones 9-slice Kenney UI.
B. Personajes: colisión sólida en NPCs (StaticBody) + zona de interacción más grande; sombra bajo sprites; el hint de "E:" sale encima del NPC en vez de en una esquina.
C. Assets/ambiente (HECHO: iconos de objetos, luz/oscuridad, arte propio de clases/enemigos; pendiente: suelo por tramo, animación andar/idle, partículas, título): iconos de objetos en inventario/tienda (tiles 103-131 ya descargados); suelo variado por tramo de pisos; animación en código (andar/idle, orientación); luz/oscuridad con CanvasModulate + PointLight2D; partículas de golpe; pantalla de título.

## Notas de sesión (2026-10-14)
- Fase 0 y 1 commiteadas (40180b2, f118afa). Godot 4.2.2 en /Applications/Godot.app.
- Se instaló el MCP godot (`@coding-solo/godot-mcp`, GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot). Tras reiniciar: verificar con `/mcp` y probar run_project + get_debug_output.
- Siguiente: Fase 2 (hub con tienda/descanso, torre por pisos, escaleras, jefe por piso, enemigos visibles en mapa, dificultad creciente).
- Cuidado: abrir el proyecto en Godot con "Importar", nunca "Nuevo proyecto" (sobrescribe project.godot). Si cambias class_name nuevas, correr `Godot --headless --path . --import`.
- Tests headless de apoyo: scripts SceneTree con `--script` (simulan combate, inventario, guardado).

## Plan pulido D (hecho en una pasada; sin música)
1. [x] Bug: la UI de combate no se ocultaba al acabar (ahora tras 1.3 s, para leer el log)
2. [x] Entradas: acciones `interact/inventory/hub/pause` (teclado + mando), foco inicial en menús, estilo de foco visible
3. [x] Pantalla de título (Continuar / Nueva partida con confirmación / Salir) como escena principal
4. [x] Menú de pausa (Esc/Start): continuar, controles, menú principal (guarda)
5. [x] Aviso al subir de nivel / aprender habilidad (diálogo tras el combate + log)
6. [x] Suelo por tramo de pisos (tile + tinte, cada 5 pisos)
7. [x] Idle de NPCs, enemigos y sprites de combate; números de daño flotantes
Aplazado: música de fondo.

## Plan E: retratos de PNJ + combate con símbolos (estilo Slay the Spire)
1. [x] Retratos: `npcs/<nombre>_face.png` (recorte de cabeza y torso) en diálogos (anciano, posadera) y tienda (mercader)
2. [x] `Icons` (símbolos de 7x7 con contorno generados en código) + `Bar` (barra con número)
3. [x] Intenciones: cada enemigo decide su próxima acción al acabar la anterior y la muestra sobre su sprite (icono + daño previsto, aturdido); el turno la ejecuta tal cual
4. [x] Daño total que recibirás esta ronda sobre el jugador; barras HP/MP en vez de texto; estados como iconos con turnos
5. [x] Quitar líneas de log redundantes (daño, habilidades): el nombre de la habilidad sale flotando; iconos en el menú de habilidades
6. [x] Tests (intenciones coherentes con lo que ocurre) + capturas + sim_balance sin regresión

## Plan G: builds por run + metaprogresión (propuesta, pendiente de confirmar)
Decisiones tomadas: progresión **por run** (nivel, habilidades elegidas y reliquias se reinician en cada bajada); al morir se pierde solo la build del run; el oro **persiste** para que el mercader del hub tenga sentido.
- **Run** = una bajada a la torre. Muerte o retirada → vuelta al hub, build nueva en el siguiente run.
- **Oro** (persistente, se conserva al morir): lo gasta el mercader en la *preparación del run* (consumibles que llevas, equipo inicial de un tier). Equipo y objetos hallados en el run se pierden con él.
- **Esencia** (persistente): de jefes y de pisos nuevos (más si superas tu récord); se gasta en el altar del hub.

**G1 Núcleo de run (sin meta)**
1. [x] Run separado del guardado: `SaveGame.save(null, …)` guarda solo la meta (oro, piso máx., misiones); `run_floor` = piso más profundo del run, las escaleras del hub vuelven a él (un run nuevo empieza en el piso 1).
2. [x] Subida de nivel = elegir 1 de 3 mejoras (stats, habilidades de la clase, pasivas); fuera el desbloqueo fijo por nivel. Máx. 4 habilidades equipadas.
3. [x] Reliquias: tras cada jefe, elegir 1 de 3 (~10 iniciales: sangrado+, curar al matar, daño con poca vida…) con ganchos en `battle_system` (al golpear, al matar, inicio de turno).
4. [x] Muerte = fin de run: pantalla resumen (Esencia ganada), vuelta al hub, build reiniciada. Test de flujo.
**G2 Economía y mercader**
5. [x] Oro persistente (también al morir, +10 por piso alcanzado); el mercader solo vende equipo básico (valor ≤ 60) y consumibles con mochila de 4; lo mejor cae en la torre.
6. [x] Migración del guardado: hecha en G1 (los guardados antiguos cargan como run en curso).
**G3 Altar (meta)**
7. [x] Altar en el hub (`AltarMenu`, `Meta`): Esencia (1 por enemigo, 5+2/piso por jefe, +10 por piso récord) y 10 mejoras: Vitalidad, Fuerza, Guardia, Celeridad, Mente, Codicia, Mochila, Iniciado, Herencia, Retorno. Pendiente: atajo de piso y desbloqueo de clases/habilidades/reliquias.
**G4 Dificultad adaptable**
8. [ ] Pactos voluntarios (más dificultad ⇒ más Esencia/oro) y ayuda suave tras varias muertes seguidas; `FLOOR_EASE` pasa a ser la base.
**G5 Balance**
9. [ ] `sim_balance` con elecciones de build; ajustar para que un run medio llegue al piso 5–8 sin meta.
