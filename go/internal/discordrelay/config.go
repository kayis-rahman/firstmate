// Package discordrelay is a deterministic, zero-model-token Discord relay for
// firstmate: captain-only capture into bin/fm-inbox.sh, threaded replies,
// urgent alerts, batched routine updates and one unanswered-question reminder.
package discordrelay

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"time"
)

// Config is read from config/discord-relay.json. It never holds the bot token,
// only the name of the environment variable that does.
type Config struct {
	Enabled      bool   `json:"enabled"`
	ChannelID    string `json:"channel_id"`
	OwnerID      string `json:"owner_id"`
	TokenEnv     string `json:"token_env"`
	StateDir     string `json:"state_dir"`
	InboxCmd     string `json:"inbox_cmd"`
	PollSeconds  int    `json:"poll_seconds"`
	ReminderSecs int    `json:"reminder_seconds"`
	BatchSecs    int    `json:"batch_seconds"`
}

var snowflake = regexp.MustCompile(`^[0-9]{5,25}$`)

// LoadConfig reads and validates a config file, applying defaults.
func LoadConfig(path string) (Config, error) {
	var c Config
	b, err := os.ReadFile(path)
	if err != nil {
		return c, err
	}
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&c); err != nil {
		return c, fmt.Errorf("config %s: %w", path, err)
	}
	return c, c.Validate()
}

// Validate applies defaults and refuses unsafe or incomplete settings.
func (c *Config) Validate() error {
	if !snowflake.MatchString(c.ChannelID) {
		return errors.New("channel_id must be a Discord snowflake")
	}
	if !snowflake.MatchString(c.OwnerID) {
		return errors.New("owner_id must be a Discord snowflake")
	}
	if c.StateDir == "" {
		return errors.New("state_dir is required")
	}
	def := func(p *int, v int) {
		if *p <= 0 {
			*p = v
		}
	}
	def(&c.PollSeconds, 5)
	def(&c.ReminderSecs, 60)
	def(&c.BatchSecs, 600)
	if c.TokenEnv == "" {
		c.TokenEnv = "FM_DISCORD_RELAY_TOKEN"
	}
	if c.InboxCmd == "" {
		c.InboxCmd = "bin/fm-inbox.sh"
	}
	return nil
}

func (c Config) reminderAfter() time.Duration { return time.Duration(c.ReminderSecs) * time.Second }
func (c Config) batchWindow() time.Duration   { return time.Duration(c.BatchSecs) * time.Second }
