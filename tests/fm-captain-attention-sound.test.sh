#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODULE="$ROOT/.pi/extensions/lib/fm-captain-attention-sound.ts"
node --experimental-strip-types --input-type=module - "$MODULE" <<'JS'
const { createCaptainAttentionSound } = await import(process.argv[2]);
const { existsSync } = await import("node:fs");
const played = [];
const sound = createCaptainAttentionSound({ platform: "darwin", play: (file) => played.push(file) });
if (!sound.outcome("captain", false, "seq-1")) throw new Error("first outcome did not play");
if (sound.outcome("captain", false, "seq-1")) throw new Error("duplicate outcome retriggered");
if (played.length !== 1 || !played[0].endsWith("assets/captain-attention.wav") || !existsSync(played[0])) throw new Error("wrong or missing playback asset");
sound.clear("captain-outcome", "seq-1");
if (!sound.outcome("captain", false, "seq-1") || played.length !== 2) throw new Error("cleared condition did not reset");
const quiet = createCaptainAttentionSound({ disabled: true, play: () => { throw new Error("disabled playback invoked"); } });
if (quiet.notify("actionable-blocker", "blocked-1")) throw new Error("disabled sound reported playback");
const broken = createCaptainAttentionSound({ play: () => { throw new Error("device unavailable"); } });
if (!broken.notify("watcher-failure", "failure-1")) throw new Error("playback failure suppressed event handling");
const other = createCaptainAttentionSound({ platform: "linux" });
if (!other.notify("watcher-failure", "failure-2")) throw new Error("non-mac event handling failed");
if (!sound.outcome("captain", false, "next") || played.length !== 3) throw new Error("captain outcome was not played");
if (sound.outcome("routine", false, "routine") || sound.outcome("captain", true, "silent")) throw new Error("routine or silent outcome triggered sound");
console.log("captain attention sound policy passed");
JS
