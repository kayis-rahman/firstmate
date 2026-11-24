// fm-discord-relay: deterministic, zero-model-token Discord relay for firstmate.
//
//	fm-discord-relay run    [-config f]   loop until SIGINT/SIGTERM
//	fm-discord-relay once   [-config f]   one pass (shadow/testing)
//	fm-discord-relay emit   [-config f] -kind K [-task T] [-id ID] text...
//	fm-discord-relay status [-config f]   counters only, no message text
//
// It is off unless the config file says "enabled": true. See
// docs/discord-relay.md. The bot token is read only from the environment
// variable named by token_env and is never logged.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/firstmate/firstmate/internal/discordrelay"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: fm-discord-relay run|once|emit|status [-config file]")
		os.Exit(2)
	}
	cmd := os.Args[1]
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	home := os.Getenv("FM_HOME")
	cfgPath := fs.String("config", filepath.Join(home, "config", "discord-relay.json"), "config file")
	kind := fs.String("kind", "", "emit: decision|review-ready|login|blocker or a routine kind")
	task := fs.String("task", "", "emit: task id")
	id := fs.String("id", "", "emit: stable event id (default: hash of kind+task+text)")
	_ = fs.Parse(os.Args[2:])

	cfg, err := discordrelay.LoadConfig(*cfgPath)
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	if cmd == "emit" {
		// Hooks must work even when the relay is disabled or down: the event
		// file waits durably for the next pass.
		text := strings.Join(fs.Args(), " ")
		eid := *id
		if eid == "" {
			h := sha256.Sum256([]byte(*kind + "\x00" + *task + "\x00" + text))
			eid = *kind + "-" + hex.EncodeToString(h[:6])
		}
		if err := discordrelay.WriteEvent(filepath.Join(cfg.StateDir, "events"), discordrelay.EventIn{ID: eid, Kind: *kind, Task: *task, Text: text}); err != nil {
			log.Fatalf("fm-discord-relay emit: %v", err)
		}
		fmt.Println(eid)
		return
	}
	if cmd != "run" && cmd != "once" && cmd != "status" {
		log.Fatalf("fm-discord-relay: unknown command %q", cmd)
	}
	if cmd != "status" && !cfg.Enabled {
		log.Fatalf("fm-discord-relay: disabled; set \"enabled\": true in %s to start it", *cfgPath)
	}
	st, err := discordrelay.OpenStore(cfg.StateDir)
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	defer st.Close()
	if cmd == "status" {
		s := st.S
		pending := 0
		for _, m := range s.Messages {
			if !m.Rejected && !m.Enqueued {
				pending++
			}
		}
		fmt.Printf("cursor=%s messages=%d pending_enqueue=%d rejected=%d events=%d batch=%d reply_cursor=%s\n",
			s.Cursor, len(s.Messages), pending, s.Rejected, len(s.Events), len(s.Batch), s.ReplyCursor)
		return
	}
	token := os.Getenv(cfg.TokenEnv)
	if token == "" {
		log.Fatalf("fm-discord-relay: environment variable %s is empty", cfg.TokenEnv)
	}
	inbox := cfg.InboxCmd
	if !filepath.IsAbs(inbox) {
		inbox = filepath.Join(home, inbox)
	}
	r := &discordrelay.Relay{
		Cfg:  cfg,
		Chat: &discordrelay.HTTPChat{Base: cfg.APIBase, Channel: cfg.ChannelID, Token: token},
		Box:  discordrelay.ExecInbox{Cmd: inbox, Home: home},
		St:   st,
		Now:  time.Now,
		Logf: log.Printf,
	}
	if cmd == "once" {
		if err := r.Tick(); err != nil {
			log.Fatalf("fm-discord-relay: %v", err)
		}
		return
	}
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	t := time.NewTicker(time.Duration(cfg.PollSeconds) * time.Second)
	defer t.Stop()
	for {
		if err := r.Tick(); err != nil {
			log.Printf("tick: %v", err)
		}
		select {
		case <-sig:
			return
		case <-t.C:
		}
	}
}
