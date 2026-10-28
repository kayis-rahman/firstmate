# Firstmate migration checkpoint

Direction B (adopt in place, no move) was used to bring the existing plain
firstmate home into the Infinitary system.

- Source home: /Users/kayisrahman/Documents/workspace/firstmate (this repository's root)
- Infinitary app home: /Users/kayisrahman/Library/Application Support/infinitary/firstmate/home
- Adoption: the empty app home was renamed to `home.pre-migration-empty-checkpoint`
  and replaced with a symlink to the source home above.
- Data, state and config are left in place; nothing was copied.
- Validation: FM_HOME set to the app home symlink resolves to the source home and
  data/, state/, config/ are readable through it; bundled scripts run against it.
