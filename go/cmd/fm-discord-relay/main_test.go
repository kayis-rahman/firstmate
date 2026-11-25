package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/firstmate/firstmate/internal/discordrelay"
)

func TestEmitRequiresEnabledConfig(t *testing.T) {
	if os.Getenv("FM_TEST_DISCORD_EMIT") == "1" {
		os.Args = []string{os.Args[0], "emit", "-kind", "blocker", "-id", "test", "queued while stopped"}
		main()
		return
	}
	home, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	cfg := discordrelay.Config{ChannelID: "12345", OwnerID: "67890", StateDir: filepath.Join(home, "relay")}
	st, err := discordrelay.OpenStore(cfg.StateDir, discordrelay.Scope{ChannelID: cfg.ChannelID, OwnerID: cfg.OwnerID, InboxHome: home})
	if err != nil {
		t.Fatal(err)
	}
	st.Close()
	configDir := filepath.Join(home, "config")
	if err := os.Mkdir(configDir, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FM_HOME", home)
	t.Setenv("FM_TEST_DISCORD_EMIT", "1")
	t.Setenv("FM_DISCORD_RELAY_TOKEN", "")
	for _, enabled := range []bool{false, true} {
		cfg.Enabled = enabled
		b, err := json.Marshal(cfg)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(configDir, "discord-relay.json"), b, 0o600); err != nil {
			t.Fatal(err)
		}
		out, runErr := exec.Command(os.Args[0], "-test.run=^TestEmitRequiresEnabledConfig$").CombinedOutput()
		files, err := os.ReadDir(filepath.Join(cfg.StateDir, "events"))
		if err != nil {
			t.Fatal(err)
		}
		if !enabled && (runErr == nil || !strings.Contains(string(out), "disabled") || len(files) != 0) {
			t.Fatalf("disabled emit did not refuse cleanly: %v, %s, %v", runErr, out, files)
		}
		if enabled && (runErr != nil || len(files) != 1) {
			t.Fatalf("enabled emit did not queue while stopped: %v, %s, %v", runErr, out, files)
		}
	}
}
