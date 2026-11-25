// Package discordrelay is a deterministic, zero-model-token Discord relay for
// firstmate: captain-only capture into bin/fm-inbox.sh, threaded replies,
// urgent alerts and an unanswered-question reminder.
package discordrelay

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
)

// Config is read from config/discord-relay.json.
type Config struct {
	Enabled   bool   `json:"enabled"`
	ChannelID string `json:"channel_id"`
	OwnerID   string `json:"owner_id"`
	StateDir  string `json:"state_dir"`
}

var snowflake = regexp.MustCompile(`^[0-9]{5,25}$`)

// LoadConfig reads and validates a config file.
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
	if err := dec.Decode(new(json.RawMessage)); err != io.EOF {
		return c, fmt.Errorf("config %s: expected exactly one JSON object", path)
	}
	return c, c.Validate()
}

// Validate refuses unsafe or incomplete settings.
func (c *Config) Validate() error {
	if !snowflake.MatchString(c.ChannelID) {
		return errors.New("channel_id must be a Discord snowflake")
	}
	if !snowflake.MatchString(c.OwnerID) {
		return errors.New("owner_id must be a Discord snowflake")
	}
	if !filepath.IsAbs(c.StateDir) {
		return errors.New("state_dir must be an absolute path")
	}
	return nil
}
