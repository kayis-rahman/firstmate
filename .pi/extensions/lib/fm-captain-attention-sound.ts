import { spawn as nodeSpawn } from "node:child_process";
import { setInterval as nodeSetInterval, clearInterval as nodeClearInterval } from "node:timers";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

export type AttentionEvent = "captain-outcome" | "actionable-blocker" | "watcher-failure";
type RepeatTimer = { cancel(): void };
export type SoundOptions = {
  platform?: string;
  disabled?: boolean;
  play?: (asset: string) => void;
  repeatIntervalMs?: number;
  scheduleRepeat?: (callback: () => void, intervalMs: number) => RepeatTimer;
};

const asset = resolve(dirname(fileURLToPath(import.meta.url)), "../../../assets/captain-attention.wav");
const DEFAULT_REPEAT_INTERVAL_MS = 30_000;

export function createCaptainAttentionSound(options: SoundOptions = {}) {
  const seen = new Set<string>();
  const repeatTimers = new Map<string, RepeatTimer>();
  const canPlay = Boolean(options.play) || (options.platform ?? process.platform) === "darwin";
  const play = () => {
    if (options.play) {
      try { options.play(asset); } catch { /* Audio is optional and must not affect fleet work. */ }
    } else if ((options.platform ?? process.platform) === "darwin") {
      try {
        const child = nodeSpawn("afplay", [asset], { detached: true, stdio: "ignore" });
        child.on("error", () => {});
        child.unref();
      } catch { /* Audio is optional and must not affect fleet work. */ }
    }
  };
  const scheduleRepeat = options.scheduleRepeat ?? ((callback, intervalMs) => {
    const timer = nodeSetInterval(callback, intervalMs);
    timer.unref();
    return { cancel: () => nodeClearInterval(timer) };
  });
  return {
    outcome(verdict: "captain" | "routine", silent: boolean, key: string): boolean {
      return verdict === "captain" && !silent ? this.notify("captain-outcome", key) : false;
    },
    notify(event: AttentionEvent, key: string): boolean {
      if (options.disabled ?? (process.env.FM_CAPTAIN_ATTENTION_SOUND === "0" || process.env.FM_CAPTAIN_ATTENTION_SOUND === "off")) return false;
      if (!key || seen.has(`${event}:${key}`)) return false;
      const id = `${event}:${key}`;
      seen.add(id);
      play();
      const intervalMs = options.repeatIntervalMs ?? DEFAULT_REPEAT_INTERVAL_MS;
      if (event === "captain-outcome" && canPlay && Number.isFinite(intervalMs) && intervalMs > 0) {
        repeatTimers.set(id, scheduleRepeat(() => {
          if (seen.has(id)) play();
        }, intervalMs));
      }
      return true;
    },
    clear(event: AttentionEvent, key: string): void {
      const id = `${event}:${key}`;
      seen.delete(id);
      repeatTimers.get(id)?.cancel();
      repeatTimers.delete(id);
    },
  };
}
