#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODULE="$ROOT/.pi/extensions/lib/fm-captain-attention-sound.ts"
node --experimental-strip-types --input-type=module - "$MODULE" <<'JS'
const { createCaptainAttentionSound } = await import(process.argv[2]);
const { existsSync } = await import("node:fs");
const played = [];
const timers = [];
const sound = createCaptainAttentionSound({
  platform: "darwin",
  play: (file) => played.push(file),
  scheduleRepeat: (callback, intervalMs) => {
    if (intervalMs !== 30000) throw new Error(`unexpected repeat interval: ${intervalMs}`);
    const timer = { callback, cancelled: false, cancel() { this.cancelled = true; } };
    timers.push(timer);
    return timer;
  },
});
if (!sound.outcome("captain", false, "seq-1")) throw new Error("first outcome did not play");
if (played.length !== 1 || timers.length !== 1) throw new Error("first outcome did not start one repeat timer");
if (!played[0].endsWith("assets/captain-attention.wav") || !existsSync(played[0])) throw new Error("wrong or missing playback asset");
timers[0].callback();
if (played.length !== 2) throw new Error("unacknowledged outcome did not repeat");
if (sound.outcome("captain", false, "seq-1")) throw new Error("duplicate outcome created another repeat loop");
if (timers.length !== 1) throw new Error("duplicate outcome created a second repeat timer");
sound.clear("captain-outcome", "seq-1");
if (!timers[0].cancelled) throw new Error("acknowledgement did not cancel the repeat timer");
timers[0].callback();
if (played.length !== 2) throw new Error("acknowledged outcome played again");
if (!sound.outcome("captain", false, "seq-1") || played.length !== 3 || timers.length !== 2) throw new Error("cleared condition did not restart playback and repetition");
const quiet = createCaptainAttentionSound({ disabled: true, play: () => { throw new Error("disabled playback invoked"); } });
if (quiet.notify("actionable-blocker", "blocked-1")) throw new Error("disabled sound reported playback");
const broken = createCaptainAttentionSound({ play: () => { throw new Error("device unavailable"); } });
if (!broken.notify("watcher-failure", "failure-1")) throw new Error("playback failure suppressed event handling");
const other = createCaptainAttentionSound({
  platform: "linux",
  scheduleRepeat: () => { throw new Error("unsupported platform started a repeat timer"); },
});
if (!other.notify("watcher-failure", "failure-2")) throw new Error("non-mac event handling failed");
if (!other.outcome("captain", false, "unsupported-platform")) throw new Error("unsupported platform changed captain outcome handling");
if (!sound.notify("actionable-blocker", "blocked-2") || !sound.notify("watcher-failure", "failure-3")) throw new Error("non-outcome alert behavior changed");
if (timers.length !== 2) throw new Error("non-outcome alert started a repeat timer");
if (!sound.outcome("captain", false, "next") || played.length !== 6 || timers.length !== 3) throw new Error("captain outcome was not played and repeated");
if (sound.outcome("routine", false, "routine") || sound.outcome("captain", true, "silent")) throw new Error("routine or silent outcome triggered sound");
if (timers.length !== 3) throw new Error("routine or silent outcome started repetition");
console.log("captain attention sound policy passed");
JS
