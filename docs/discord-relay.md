# Discord relay (Go, off by default)

`fm-discord-relay` is a deterministic Discord relay for one captain and one channel.
It makes no language-model calls: it authorizes the sender, captures messages into [`bin/fm-inbox.sh`](../bin/fm-inbox.sh), adds seen and acknowledged reactions, posts threaded answers and alerts when firstmate needs the captain.
It is a separate private tool beside the current bridge in [discord-voice-relay.md](discord-voice-relay.md); building it changes nothing about that bridge.
Nothing in this repository installs a LaunchAgent for it or starts it automatically.

The Go relay does not handle voice notes, reaction polls, slash commands, the away-mode webhook, or the front-desk secondmate.
Buttons and select menus, and replacing the front-desk mate, are follow-ups.

## What it does

| Stage | Behaviour |
| --- | --- |
| Capture | Polls the configured channel over the Discord REST API. Only messages whose author id equals `owner_id` in `channel_id` are accepted; bots, other users and other channels are ignored. |
| Enqueue | Runs `fm-inbox.sh note --request-id discord-<messageId> --json`. The request id makes a retry or replay return the original note. The message is stored durably before the read cursor advances, and retried every pass until the inbox accepts and announces it. |
| Seen | The relay adds a 👀 reaction after it saves the capture, even if inbox enqueue or wake fails. |
| Acknowledged | The relay adds a ✅ reaction only after `fm-inbox.sh receipts --all-handled` reports the note handled. Both reactions are idempotent and recorded in `state.json` only after Discord accepts them. |
| Answers | Reads `fm-inbox.sh receipts --all-replies --after <cursor>` and posts native threaded replies. A stable nonce deduplicates retries within Discord’s short nonce window; a later retry after an ambiguous send can duplicate the reply. If the parent is missing, that answer stays queued and the error is logged; other mapped answers can still post. No standalone answer is posted. |
| Urgent alerts | The only accepted event kinds are `decision`, `review-ready`, `login`, and `blocker`. They are posted immediately and can push with the notification setup below. They post silently if the most recent observed captain message was within the last two minutes. On first start, alerts wait for the baseline to be saved. With a saved cursor, an incomplete inbound pass does not delay an alert; it can still push if recent owner activity has not been observed. |
| Reminder | An alert without a later captain text reply referencing that alert gets a threaded “Still waiting on you” reminder after one minute. Other owner chat only counts as presence. Recent owner activity or an incomplete inbound pass holds the reminder without canceling it. Rejected sends remain eligible; the relay records completion only after Discord accepts the reminder. |
| Secrets | All posts have mentions disabled, a fixed length cap, and best-effort credential redaction. Do not send sensitive text or rely on the filter to make it safe. |

On first start the relay baselines at the newest message without replaying history. Recent owner messages seen on the first page, including messages without text, count as presence but are not replayed into the inbox. A full baseline page may hide recent activity, so reminders wait two minutes after the baseline is saved and require a successful inbound pass. This in-memory hold does not delay alerts. A restart within about two minutes of a first start with a full baseline page loses the hold and may allow one early reminder.

## Configuration

See [Go Discord relay configuration](configuration.md#go-discord-relay) for the schema, operational home, and bot token.

Shadow testing requires **both** a separate channel and a separate bot token from the live bridge. The relay channel must be captain-only and private in both shadow and live environments; the sender check does not restrict who can read posts.
`state_dir` holds `state.json` (mode 0600, atomically replaced), `relay.lock` and `events/`. The lock prevents a second relay using the same state directory, not another reader of the channel. The relay binds the state to its channel, owner, and inbox home and refuses mismatches.
Relay state and the event spool can contain captain messages and alert text, so keep the directory private.

## Commands

```sh
# From the repository root:
bin/fm-go-pilot-build.sh
bin/go-pilot/discord-relay run
bin/go-pilot/discord-relay emit -kind blocker -id blocker-001 "short text"
```

## Event hooks

Use `emit` to queue events. The private, scope-checked `events/` directory is the producer trust boundary; grant write access only to trusted producers. First start the relay to bind the state directory; `emit` refuses an unbound directory or a mismatch in channel, owner, or inbox home. Once bound, `emit` can queue events whether or not the reader is running. Spool filenames are the lowercase hex encoding of the exact occurrence ID followed by `.json`.
The relay stores events durably before delivery and deduplicates by occurrence ID.
Use an explicit occurrence ID, reusing it only when retrying the same occurrence.
Alerts and reminders are delivered at least once: a crash after Discord accepts the post but before local state is saved can duplicate it. If the relay crashes before saving an alert’s Discord ID, a reply to that visible copy is still captured, but may not match the retried alert, so a reminder may follow.
This release is shadow-only. Connecting the live Firstmate status producer is a separate cutover step that requires captain approval; `emit` is not wired into that producer.

## Shadow test, cutover and rollback

For both shadow and live use, set the captain’s Discord notification setting for the relay channel to **All Messages**, leave the channel unmuted, and enable push notifications on the receiving device. The relay does not use mentions to trigger alerts or reminders.

Stop the relay before changing the bot’s channel permissions. Losing **Read Message History** can look like an empty channel at baseline or no new messages during polling. Restore the required permissions before restarting.

Shadow test (needs the captain's word; nothing here is done by the build):

1. Use a separate captain-only test channel and bot token. Before baselining a guild text channel, enable **Message Content Intent** for the bot in the Discord Developer Portal (and obtain approval if Discord requires it). Before baselining, grant the bot **View Channel**, **Read Message History**, **Send Messages**, and **Add Reactions** in the shadow channel. Export the shadow token as `FM_DISCORD_RELAY_TOKEN` and set `FM_HOME` to an existing throwaway inbox home, not the live home. Write a config with `enabled: true`, the shadow channel and a fresh shadow `state_dir`. Before running the inbox commands manually, unset the overrides listed in the [configuration reference](configuration.md#go-discord-relay) so they use the same home paths as the relay.
2. Start `bin/go-pilot/discord-relay run` under supervision. After the initial baseline is saved, send an ordinary captain message that does not mention the bot. On a subsequent poll, confirm it gets 👀 and appears in `bin/fm-inbox.sh list` with the same `FM_HOME`.
3. Use `bin/fm-inbox.sh reply <note-id> "test answer"` and check that the answer appears in the thread. Use `bin/fm-inbox.sh drain --ack <note-id>` and check for ✅.
4. With the relay still running, wait two quiet minutes, then emit a decision with an explicit occurrence ID from another shell using the same `FM_HOME`. Check for one push and a reminder after about a minute if unanswered.

Cutover requires the captain’s approval of the shadow results, live producer wiring, and voice-note interruption. Stopping the old watcher also stops voice-note handling until that watcher is restored.

1. Before stopping the old watcher, set `FM_DISCORD_RELAY_TOKEN` to the live bot token in the relay supervisor’s environment. Verify the live bot has **View Channel**, **Read Message History**, **Send Messages**, and **Add Reactions** in the live channel, and **Message Content Intent** for guild text. Pause normal captain text submissions before stopping the old watcher. Answer its outstanding notes and confirm the watcher delivered the replies, or hand each note off explicitly with an agreed way to deliver its answer. The Go relay does not inherit the old watcher’s reply mappings.
2. Stop the old message watcher (`launchctl bootout gui/$(id -u)/com.firstmate.discord-watcher`) so no two readers capture the same messages. Keep the existing reaction poll handling running: cast a test vote after stopping the watcher and confirm it is counted. If it fails, restart the old watcher and stop the cutover.
3. Set the relay config to the live captain-only channel and select the live inbox home. Always use a fresh live `state_dir`; never reuse shadow state. Start `bin/go-pilot/discord-relay run` under supervision at cutover; its first pass establishes the live baseline. History at or before the baseline is not replayed.
4. Confirm the initial cursor is saved in the new `state.json`, then send a fresh, ordinary captain text message that does not mention the bot. Confirm it gets 👀 and appears in `bin/fm-inbox.sh list` for the live `FM_HOME`. If either check fails, keep normal submissions paused and fix the setup or roll back. Reconcile any captain messages sent between the old watcher stopping and that baseline (resend any that did not reach the inbox), then resume normal submissions. Monitor the relay log for errors.

Rollback:

1. If a live producer was connected to the Go relay, point it back to its previous route before restarting the old watcher. With the config still enabled, `emit` can succeed even when the relay is stopped; that only queues the alert.
2. Before stopping the Go relay, check for unsent alerts in `events/` and in `state.json` (events with `posted: false`). Record pending alerts for reconciliation; the old watcher does not drain the Go alert queue.
3. Disable automatic restarts, send `SIGTERM` to the Go relay, and confirm it has exited. An in-progress pass can keep running after the signal. Only then check the captain-only channel again and post any still-needed alert by hand if it was not delivered.
4. Restart the old watcher: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.firstmate.discord-watcher.plist`.
5. Successfully enqueued messages are already in the Firstmate inbox. Captures not yet enqueued may exist only in relay state; keep that directory and reconcile those messages before deleting it. Messages sent while neither ran are picked up by the old bridge according to its own cursor. The old watcher may also repost an answer already delivered by the Go relay because it uses a separate reply cursor.
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

Known limits: presence is inferred only from the captain's own messages (a silent captain who is looking at the channel looks absent); Discord rate limits are handled by retrying at the next poll, not by honouring `Retry-After`.

## Verification

From the `go/` directory, run `go test ./internal/discordrelay/ ./cmd/fm-discord-relay/` for the relay and CLI tests.
The relay tests use a fake Discord HTTP server and a stub inbox command, not a live Discord channel.
The shadow procedure above is the live verification entry point.
