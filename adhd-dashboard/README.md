# ADHD Master Dashboard

A one-page web app built for Tucker by Claude: brain dump, top-3 daily priorities, a
"right now" focus card with 10/25-minute timers, a wins log, plus checklists for the
lost-money hunt and getting set up.

## How to use it

- Everything lives in `index.html` — no installs, no build step. Double-clicking the
  file opens a fully working copy in any browser.
- All data saves automatically in the browser (localStorage) on whatever device you
  open it on. Nothing is sent anywhere.
- The main copy runs as a private Claude artifact on claude.ai, so it works on your
  phone too.

## Saving (v2)

Data is kept in three layers: localStorage (instant), an IndexedDB mirror (survives
more than localStorage), and — optionally, in Chrome/Edge — a real JSON file on disk
that auto-writes on every change via the File System Access API. Every browser also
gets one-tap "Download backup" / "Restore from backup". The in-app "Make it a desktop
app" drawer has per-browser steps for installing the page as a windowed app.

## Why is this inside the airllm fork?

This fork was the only repo Claude's cloud session could reach, so the dashboard code
is parked here temporarily to keep it safe.

The plan:

1. Create a private repo at github.com/new (suggested name: `second-brain`).
2. Tell Claude "the repo's ready" — this folder moves there, and this fork can then be
   deleted or kept, your call.
