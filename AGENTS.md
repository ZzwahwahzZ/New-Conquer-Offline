# Agent instructions for New Conquer Offline

## Project goal
Follow the conversion scope in README.md. The immediate milestone is to make the supplied original client content run locally without connecting to the original game servers.

## Protect original material
- Preserve original APKs, compressed resource archives, and supplied source assets unchanged.
- Do not overwrite, rename, delete, recompress, or silently alter original files.
- Do not label proprietary formats as converted or Godot-ready unless a compatible conversion has actually been completed and verified.
- Keep generated, extracted, and converted outputs in clearly separate directories with manifests where appropriate.
- Do not add placeholder art, audio, models, or gameplay systems as substitutes for missing original content.

## Scope control
- Make only changes needed for the requested task and the offline-conversion milestone.
- Defer new gameplay features, economy changes, world redesign, and visual redesign unless the user explicitly requests them.
- Before any broad or destructive operation, explain the affected files and obtain approval.

## Verification
- Inspect the existing project before editing; do not assume its structure.
- Run relevant tests and import/build checks after changes.
- Clearly separate static inspection, successful imports, automated tests, and actual runtime/device validation.
- Never claim the original client runs on Android unless that exact runtime test was performed.
- Report changed files, commands run, results, and any remaining blockers honestly.

## Working style
- The user gives instructions in ordinary Arabic; respond in clear Arabic and avoid requiring the user to write code.
- Prefer small, reviewable changes and preserve a clean Git history.
- Do not commit credentials, tokens, passwords, private login files, or generated logs.
