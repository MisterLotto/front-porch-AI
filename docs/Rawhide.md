# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🎨 **Draw Things integration rebuilt — faster and far more reliable** — the app now talks to Draw Things directly instead of going through a bundled Python helper (the main reason Draw Things sometimes worked from source but broke in releases). Connection tests, model lists, and generations run in-process with live step progress; if anything goes wrong it automatically falls back to the old path, so nothing regresses while the new path proves itself.
- 🔧 Under-the-hood fixes and polish.
