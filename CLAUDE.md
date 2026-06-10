# CLAUDE.md - VampireCityRPG

## Project Overview

**Name:** Vampire City RPG  
**Type:** Godot Game (GDScript)  
**Description:** 2D RPG game built with Godot engine. Features pixel art style with a vampire/horror theme.  
**Owner:** @polidisio  

## Tech Stack

- **Engine:** Godot 4.2+ (GL Compatibility renderer)
- **Language:** GDScript
- **Platform:** Cross-platform (mobile-friendly)
- **Resolution:** 320x180 viewport (pixel art)

## Quick Start

```bash
# Open in Godot Engine
# Import project.godot
# Run (F5)
```

## File Structure

```
VampireCityRPG/
├── scenes/                # Scene files (.tscn)
├── scripts/              # GDScript files (.gd)
├── assets/               # Game assets (sprites, sounds)
├── data/                 # Game data
├── .godot/               # Godot internal
├── main.gd               # Main scene script
├── main.tscn             # Main scene
├── project.godot         # Project configuration
├── icon.svg              # Game icon
└── CLAUDE.md
```

## Project Settings

### Display
- Viewport: 320x180 (pixel art style)
- Stretch mode: viewport
- Renderer: GL Compatibility

### Features
- Mobile support (ASTC/ETC2 texture compression)
- Touch-ready input system

## Architecture

### Scene-based
- Main scene: res://scenes/level.tscn
- Scripts attached to nodes
- Resource-based data storage

## Important Rules

### Always Do
- Test on target platform before release
- Use proper asset organization

### Never Do
- Commit .godot/cache files

## Resources

- Token optimization tips: shared/claude-optimization-tips.md (Obsidian Vault)

---

**Owner:** Jose Maudisio (@polidisio)  
**Last updated:** 2026-04-24

---

---

## Workflow

### Para tareas simples
Sé directo: "Añade validación al form" — no necesitas explicar contexto.

### Para tareas complejas (>3 pasos)
1. Agent propone plan primero
2. Usuario confirma
3. Agent ejecuta
4. Agent verifica con tests

### Para cada tarea
1. **Plan** → Si son >3 pasos, escribir en `tasks/todo.md`
2. **Verify** → Confirmar antes de cambios grandes
3. **Execute** → Cambio más pequeño posible
4. **Test** → Ejecutar tests, verificar regression
5. **Document** → Actualizar si es necesario

---

## Code Quality

### SIEMPRE
- Código legible y mantenible
- Seguir convenciones del proyecto
- DRY — no duplicar lógica
- Validar input antes de procesar

### NUNCA
- Hardcodear credenciales o tokens
- "Hacky fixes" sin justificación
- Duplicar código sin razón
- Commits sin mensaje descriptivo

---

## Security

- **NUNCA hardcodear** credenciales — usar environment variables
- **NUNCA exponer** tokens en logs o errores
- **Validar input** antes de procesar
- Si hay secrets, usar `.env` y nunca commitearlo

---

## Self-Improvement

### Si cometes un error
1. Documentar en `lessons.md` — qué salió mal, por qué, cómo evitarlo
2. Actualizar este archivo si la convención no estaba clara
3. No repetir

### Si descubres algo útil
- Documentar en notas del proyecto
- Compartir con Jose si es relevante

---

## Token Optimization

### Hacer
- Agrupar múltiples requests en uno
- Editar en vez de reply (menos historial)
- Nuevo tema = nueva conversación
- Planificar en chat, construir en workspace

### Evitar
- Subir carpetas enteras — solo archivos necesarios
- Múltiples prompts cortos seguidos
- Usar Opus para tareas simples
- Mantener contexto irrelevante

**Budget:** ~88% de tokens en conversaciones largas = solo historial. Mantenerlo limpio.

---

## Resources

**Obsidian Vault:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Saraiba/`

| Recurso | Ubicación en Vault |
|---------|---------------------|
| Best practices | `shared/coding-best-practices.md` |
| Optimization tips | `shared/claude-optimization-tips.md` |
| Skills docs | `shared/openclw-skills.md` |
| Guía coding agents | `shared/guia-coding-agents.md` |

---

## Contact

**Jose Maudisio** — @polidisio
**Issues:** Abrir en GitHub o preguntar en Telegram
