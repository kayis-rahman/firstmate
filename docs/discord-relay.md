# Discord relay (Go, off by default)

`fm-discord-relay` is a deterministic Discord relay for one captain and one channel.
It makes no language-model calls: it authorizes the sender, captures messages into [`bin/fm-inbox.sh`](../bin/fm-inbox.sh), posts threaded receipts and answers, alerts when firstmate needs the captain, and batches routine updates.
It is a separate private tool beside the current bridge in [discord-voice-relay.md](discord-voice-relay.md); building it changes nothing about that bridge.
It never starts on its own: it exits unless the config file says `"enabled": true`, and nothing in this repository installs a LaunchAgent for it.

Out of scope for this first build, and left to the existing bridge: voice notes, reaction polls, slash commands, the away-mode webhook, and the front-desk secondmate.
Buttons and select menus, and replacing the front-desk mate, are follow-ups.

## What it does

| Stage | Behaviour |
| --- | --- |
| Capture | Polls the configured channel over the Discord REST API. Only messages whose author id equals `owner_id` in `channel_id` are accepted; bots, other users and other channels are ignored, and other users are only counted. |
| Enqueue | Runs `fm-inbox.sh note --request-id discord-<messageId> --json`. The request id makes a retry or replay return the original note. The message is stored durably before the read cursor advances, and retried every pass until the inbox accepts and announces it. |
| Seen | The moment a captain message is durably captured and enqueued, the relay puts a 👀 reaction on it (`receipt: reaction`, the default; `reply` posts a silent threaded "Queued for firstmate."; `none` disables). Retried until it lands, never repeated. |
| Acknowledged | Once firstmate has actually handled the note (it is in the inbox's `handled/`, read through `fm-inbox.sh receipts --all-handled`), the relay adds a ✅ reaction to the captain's message (`ack: reaction`, the default; `reply` posts a silent threaded "Handled by firstmate."; `none` disables). The mark is recorded in `state.json` only after Discord accepts it, so a failed mark is retried and a landed one is never repeated across restarts. So 👀 means "received safely", ✅ means "firstmate dealt with it". |
| Answers | Reads `fm-inbox.sh receipts --all-replies --after <cursor>` and posts each reply once as a native threaded reply to the captain's original message. |
| Urgent alerts | Event kinds `decision`, `review-ready`, `login`, `blocker` are posted immediately with a push. While the captain chatted within `active_chat_seconds` they are posted silently, since he is already looking. |
| Routine batching | Any other kind is collected and posted as one silent "Fleet update" digest every `batch_seconds`, with identical lines collapsed. |
| Reminder | An urgent alert nobody answered within `reminder_seconds` gets exactly one threaded "Still waiting on you" reply. Any captain message after the alert counts as an answer. No reminder is sent while the captain is active in chat, and the reminder is marked sent before it is posted so a crash cannot repeat it. |
| Secrets | Everything posted passes a redaction filter (webhook URLs, token shapes, `token=` pairs, bearer values, common key formats) and is capped in length. Mentions are disabled. |

On the very first start the relay records the newest existing message as its cursor and does not replay channel history.

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
  "receipt": "reaction",
  "ack": "reaction",
  "poll_seconds": 5,
  "reminder_seconds": 60,
  "active_chat_seconds": 120,
  "batch_seconds": 600
}
```

The file holds the name of the token variable, never the token.
Use a dedicated bot token for the relay (or a dedicated test channel) so that shadow testing never competes with the live bridge for the same messages.
`api_base` defaults to `https://discord.com/api/v10` and must be https.
`state_dir` holds `state.json` (mode 0600, atomically replaced), `relay.lock` (a second instance refuses to start) and `events/`.
The state file contains the captain's not-yet-enqueued message text, so keep the directory private.

## Commands

```sh
# build: bin/fm-go-pilot-build.sh builds every go/cmd tool; run with FM_HOME set
fm-discord-relay once   # one pass; use for shadow tests
fm-discord-relay run    # loop until SIGTERM; supervise it with launchd or a shell
fm-discord-relay status # counters only, never message text
fm-discord-relay emit -kind blocker -task <task-id> -id <stable-id> "short text"
```

`FM_HOME` selects the home whose `config/` and `bin/fm-inbox.sh` are used.

## Event hooks

`emit` (or any writer following the file format) drops `<state_dir>/events/<id>.json` with `{"id","kind","task","text"}`; the file is written to a temporary name and renamed.
It works while the relay is stopped, and the event is delivered at the next pass.
The relay moves an event into `state.json` before it deletes the file, deduplicates by `id`, and quarantines malformed files as `*.json.rejected`.
Use a stable `id` such as `<task>-<kind>-<head>` so a repeated hook cannot alert twice.
Without `-id`, the id is a hash of kind, task and text.
Delivery is at-least-once for alerts: a crash after Discord accepts a post but before the state is saved can repeat that one post; reminders are at-most-once.
Wiring hooks into firstmate's status path is a separate step and is not done by this build.

## Shadow test, cutover and rollback

Shadow test (needs the captain's word; nothing here is done by the build):

1. Create a dedicated test channel and bot token, put the token in the environment of the shell that runs the relay, and write a config with `enabled: true` pointing at the test channel and a throwaway `state_dir`.
2. Run `fm-discord-relay once` after sending a message from the captain's phone; confirm the note appears in `fm-inbox.sh list`, the message gets 👀 at once and ✅ after you ack the note (`fm-inbox.sh drain --ack` or a reply), and `fm-inbox.sh reply` answers arrive in the thread.
3. Emit a `decision` event and a routine event; confirm one push, one quiet digest, and one reminder after about a minute that stops when the captain answers.
4. Send a message from a second account and confirm nothing is enqueued and `status` shows `rejected=1`.

Cutover, only after the captain approves the shadow results:

1. Stop the old message watcher (`launchctl bootout gui/$(id -u)/com.firstmate.discord-watcher`), so two readers never capture the same message. The bridge's voice, poll, slash-command and webhook parts need their own decision before they are stopped.
2. Point the relay config at the live `channel_id`, keep the relay's cursor baseline (first start skips history), and start `fm-discord-relay run` under supervision.
3. Watch `status` and the log for one day.

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
| Two relays | The second refuses to start (state lock). |

Reaction polls stay with the existing bridge; the relay handles text only (voice, buttons and selects, and replacing the front-desk mate are follow-ups).

Known limits: presence is inferred only from the captain's own messages (a silent captain who is looking at the channel looks absent); Discord rate limits are handled by retrying at the next poll, not by honouring `Retry-After`.

## Verification

`go test ./internal/discordrelay/` runs against a fake Discord HTTP server and a fake inbox, and covers capture, the seen and acknowledged marks (once across restarts, retried after a failed mark) and threaded replies, restart replay, duplicate delivery, unauthorized senders, bots and wrong channels, urgent versus batched delivery, reminder timing, once-only and suppression, quiet alerts while active, secret redaction, the single-instance lock and the real `fm-inbox.sh` exec path against a stub.
No live Discord test has been run.
