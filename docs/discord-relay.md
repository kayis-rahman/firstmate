# Discord relay (Go, off by default)

`fm-discord-relay` is a deterministic Discord relay for one captain and one channel.
It makes no language-model calls: it authorizes the sender, captures messages into [`bin/fm-inbox.sh`](../bin/fm-inbox.sh), adds seen and acknowledged reactions, posts threaded answers, alerts when firstmate needs the captain, and batches routine updates.
It is a separate private tool beside the current bridge in [discord-voice-relay.md](discord-voice-relay.md); building it changes nothing about that bridge.
It never starts on its own: it exits unless the config file says `"enabled": true`, and nothing in this repository installs a LaunchAgent for it.

Out of scope for this first build, and left to the existing bridge: voice notes, reaction polls, slash commands, the away-mode webhook, and the front-desk secondmate.
Buttons and select menus, and replacing the front-desk mate, are follow-ups.

## What it does

| Stage | Behaviour |
| --- | --- |
| Capture | Polls the configured channel over the Discord REST API. Only messages whose author id equals `owner_id` in `channel_id` are accepted; bots, other users and other channels are ignored, and other users are only counted. |
| Enqueue | Runs `fm-inbox.sh note --request-id discord-<messageId> --json`. The request id makes a retry or replay return the original note. The message is stored durably before the read cursor advances, and retried every pass until the inbox accepts and announces it. |
| Seen | The relay adds a 👀 reaction after it saves the capture, even if inbox enqueue or wake fails. |
| Acknowledged | The relay adds a ✅ reaction only after `fm-inbox.sh receipts --all-handled` reports the note handled. Both reactions are idempotent and recorded in `state.json` only after Discord accepts them. |
| Answers | Reads `fm-inbox.sh receipts --all-replies --after <cursor>` and posts native threaded replies. A stable nonce deduplicates retries within Discord’s short nonce window; a later retry after an ambiguous send can duplicate the reply. If the parent is missing, the answer stays queued and the error is logged; no standalone answer is posted. |
| Urgent alerts | Event kinds `decision`, `review-ready`, `login`, `blocker` are posted immediately with a push. While the captain chatted within the last two minutes they are posted silently, since he is already looking. |
| Routine batching | Other event kinds are posted in silent “Fleet update” digests at `batch_seconds` intervals, with identical lines collapsed. Updates that do not fit stay queued for the next digest; an oversized individual line is shortened. |
| Reminder | An urgent alert without a later captain text message gets a threaded “Still waiting on you” reminder after `reminder_seconds`. Recent owner activity holds the reminder without canceling it. Rejected sends remain eligible; the relay records completion only after Discord accepts the reminder. |
| Secrets | All posts have mentions disabled, a fixed length cap, and best-effort credential redaction. Do not send sensitive text or rely on the filter to make it safe. |

On first start the relay baselines at the newest message without replaying history. Recent owner messages, including messages without text, count as presence but are not replayed into the inbox.

## Configuration

`config/discord-relay.json` (gitignored with the rest of `config/`; override with `-config`):

```json
{
  "enabled": false,
  "channel_id": "<channel snowflake>",
  "owner_id": "<captain's Discord user snowflake>",
  "state_dir": "/absolute/path/for/relay/state",
  "token_env": "FM_DISCORD_RELAY_TOKEN",
  "inbox_cmd": "bin/fm-inbox.sh",
  "poll_seconds": 5,
  "reminder_seconds": 60,
  "batch_seconds": 600
}
```

The file holds the name of the token variable, never the token.
Shadow testing requires **both** a separate channel and a separate bot token from the live bridge. The relay channel must be captain-only and private in both shadow and live environments; the sender check does not restrict who can read posts.
`state_dir` holds `state.json` (mode 0600, atomically replaced), `relay.lock` and `events/`. The lock prevents a second relay using the same state directory, not another reader of the channel. The relay binds the state to its channel, owner, and inbox home and refuses mismatches.
The state file contains the captain's not-yet-enqueued message text, so keep the directory private.

## Commands

```sh
# From the repository root:
bin/fm-go-pilot-build.sh
bin/go-pilot/discord-relay once
bin/go-pilot/discord-relay run
bin/go-pilot/discord-relay emit -kind blocker -task <task-id> -id <occurrence-id> "short text"
```

`FM_HOME` selects the operational home for both configuration and inbox data. The default inbox wrapper is `bin/fm-inbox.sh` under the code root, inferred from the built executable’s location. Set `FM_ROOT_OVERRIDE` when running the binary outside that layout. An explicit relative `inbox_cmd` is also resolved under the code root.

## Event hooks

`emit` (or any writer following the file format) drops `<state_dir>/events/<id>.json` with `{"id","kind","task","text"}`; the file is written to a temporary name and renamed.
It works while the relay is stopped, and the event is delivered at the next pass.
The relay moves an event into `state.json` before it deletes the file, deduplicates by `id`, and quarantines malformed files as `*.json.rejected`.
Use an explicit occurrence ID, reusing it only when retrying the same occurrence.
Alerts and reminders are delivered at least once: a crash after Discord accepts the post but before local state is saved can duplicate it.
This release is shadow-only. Connecting the live Firstmate status producer is a separate cutover step that requires captain approval; `emit` and the event file format are not wired into that producer.

## Shadow test, cutover and rollback

Shadow test (needs the captain's word; nothing here is done by the build):

1. Use a separate captain-only test channel and bot token. Export the shadow token and set `FM_HOME` to an existing throwaway inbox home, not the live home. Write a config with `enabled: true`, the shadow channel and a fresh shadow `state_dir`.
2. Run `bin/go-pilot/discord-relay once` before sending a captain message to establish the baseline. Send the message, then run `once` again; confirm it gets 👀 and appears in `bin/fm-inbox.sh list` with the same `FM_HOME`.
3. Use `bin/fm-inbox.sh reply <note-id> "test answer"` and run `once` to see the answer in the thread. Use `bin/fm-inbox.sh drain --ack <note-id>`, then run `once` to see ✅.
4. After two quiet minutes, emit a decision and a routine event with distinct occurrence IDs. Check for one push, one quiet digest, and a reminder after about a minute if unanswered.

Cutover, only after the captain approves the shadow results and live producer wiring:

1. Stop the old message watcher (`launchctl bootout gui/$(id -u)/com.firstmate.discord-watcher`) so no two readers capture the same messages. Keep the existing reaction poll handling running: cast a test vote after stopping the watcher and confirm it is counted. If it fails, restart the old watcher and stop the cutover.
2. Set the relay config to the live captain-only channel and select the live inbox home. Always use a fresh live `state_dir`; never reuse shadow state. Run `bin/go-pilot/discord-relay once` at cutover to establish the live baseline, then supervise `bin/go-pilot/discord-relay run`. History at or before the baseline is not replayed.
3. Monitor the relay log for errors.

Rollback:

1. Stop the relay (`SIGTERM`; state is durable).
2. Restart the old watcher: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.firstmate.discord-watcher.plist`.
3. Messages the relay captured are already in the firstmate inbox. Messages sent while neither ran are picked up by the old bridge according to its own cursor.
Keep `state_dir` for diagnosis; delete it only to force a fresh baseline.

## Failure behaviour

| Failure | Result |
| --- | --- |
| Inbox script fails or is mid-restart | The message stays pending in `state.json` and is retried every pass, in order. |
| Wake not announced (`fm-inbox.sh` exit 3) | The saved note is retried with the same request id until announced. |
| Discord down, 429 or 5xx | The pass logs the error (token redacted) and tries again at the next poll; cursors only advance after durable handling. |
| Process crash | A restart reloads `state.json` and resumes every unfinished stage. |
| Corrupt `state.json` | The relay refuses to start and says so; restore a copy rather than guessing. |
| Two relays using the same state directory | The second cannot acquire that directory’s lock. |

Reaction polls stay with the existing bridge; the relay handles text only (voice, buttons and selects, and replacing the front-desk mate are follow-ups).

Known limits: presence is inferred only from the captain's own messages (a silent captain who is looking at the channel looks absent); Discord rate limits are handled by retrying at the next poll, not by honouring `Retry-After`.

## Verification

`go test ./internal/discordrelay/` runs against a fake Discord HTTP server and a fake inbox, and covers capture, the seen and acknowledged marks (once across restarts, retried after a failed mark) and threaded replies, restart replay, duplicate delivery, unauthorized senders, bots and wrong channels, urgent versus batched delivery, reminder timing, once-only and suppression, quiet alerts while active, secret redaction, the single-instance lock and the real `fm-inbox.sh` exec path against a stub.
No live Discord test has been run.
