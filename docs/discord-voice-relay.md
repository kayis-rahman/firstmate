# Local Discord voice-note relay

This page documents one local operator integration that relays the captain's Discord text and voice messages into a Firstmate home.
It is separate from Firstmate's optional public-mention Relay and from the spoken interface documented in [voice-relay.md](voice-relay.md).
The Discord bot token stays in the local, private `~/.firstmate-discord/discord-bot.env` file and must never be copied into Firstmate documentation or task records.

## Message flow

A macOS LaunchAgent named `com.firstmate.discord-watcher` keeps the local watcher running in the background.
The voice relay polls the configured Discord channel, ignores bot messages and messages from anyone except the configured owner, and writes accepted text messages to the local spool.
The Firstmate-side `state/discord-spool.check.sh` consumer moves spooled messages into `bin/fm-inbox.sh`, which is the durable queue Firstmate reads and answers.

For an owner voice note, the relay accepts an audio attachment hosted by Discord, downloads it to a private temporary directory, checks its duration, and normalizes it to mono 16 kHz audio with `ffmpeg`.
It runs the cached local Parakeet model with Hugging Face offline mode; there is no cloud transcription fallback.
The relay deletes the downloaded and normalized audio, posts the transcript back to Discord with a ten-minute confirmation request, and waits for the owner's `yes` or `no` reply or confirmation reaction.
Only an owner's affirmative confirmation writes the transcript to the spool; a rejection or timeout never queues it.
Pending confirmation records and processed message IDs persist under the private voice runtime directory so a restart can resume a posted confirmation without repeating transcription.

The slash-command bridge is a separate Node process and does not transcribe voice notes.
The ordinary Discord message path, voice confirmation path, slash-command bridge, and optional public-mention Relay are distinct integrations even when they share a bot account or channel.

## Local runtime requirements

The voice LaunchAgent runs `~/.firstmate-discord/voice-staging/watch-voice.sh`, which starts `voice_relay.py` using its dedicated `.venv`.
The `.venv` requires the same Python minor version used when its packages were installed, plus the locally cached `mlx-audio` Parakeet model.
`ffmpeg` and `ffprobe` must also be available at `/opt/homebrew/bin` on this deployment.
The relay log is `~/.firstmate-discord/watch.log`; diagnostics identify the failing stage and exception type without logging transcripts, bot credentials, or attachment URLs.

When Homebrew removes or upgrades the Python runtime and the venv's interpreter links stop working, repair the existing environment without removing its installed packages:

```sh
brew install python@3.11
python3.11 -m venv --upgrade ~/.firstmate-discord/voice-staging/.venv
~/.firstmate-discord/voice-staging/.venv/bin/python -c 'import mlx_audio; print("local speech runtime ready")'
```

After the import check succeeds, restart the LaunchAgent and verify that exactly one `voice_relay.py` process is running:

```sh
launchctl kickstart -k "gui/$(id -u)/com.firstmate.discord-watcher"
launchctl list | grep com.firstmate.discord-watcher
pgrep -fl voice_relay.py
```

A missing interpreter prevents the watcher script from starting and is reported clearly in `watch.log`.
A transcription failure is logged with its message ID, processing stage, and exception type, while Discord receives the generic retry message.

## Sending Firstmate replies to Discord

`bin/fm-inbox.sh reply` records a durable answer in Firstmate's inbox; it does not post that answer to Discord.
To send a message to the captain in Discord, the local operator integration uses `~/.firstmate-discord/say.sh` with the source Discord message ID, or `-` for a channel message.
Treat an inbox reply record as saved locally, not delivered externally; only report a Discord reply as sent after the posting command succeeds and the message is visible in the channel.
This local installation has no automatic inbox-reply-to-Discord outbox, so Firstmate must explicitly post each requested update through the Discord send path.

## Safe checks

Run the local unit tests without contacting Discord:

```sh
PYTHONPATH="$HOME/.firstmate-discord/voice-staging" \
  "$HOME/.firstmate-discord/voice-staging/.venv/bin/python" \
  -m unittest discover -s "$HOME/.firstmate-discord/voice-staging/tests" -v
```

Run the generated-audio end-to-end dry run to exercise local transcription, confirmation, and temporary-spool routing without Discord API calls or writes to the live spool:

```sh
"$HOME/.firstmate-discord/voice-staging/.venv/bin/python" \
  "$HOME/.firstmate-discord/voice-staging/voice_relay.py" \
  --dry-run "$HOME/.firstmate-discord/voice-staging/tests/sample.wav"
```

These checks do not prove that a live Discord attachment can be downloaded or that the Discord bot can post a reply.
Verify those behaviors only with a captain-provided voice note, then confirm that the transcript appears in Discord and reaches Firstmate only after approval.
