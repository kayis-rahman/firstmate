// fm-discord-relay: deterministic, zero-model-token Discord relay for firstmate.
//
//	fm-discord-relay run    [-config f]   loop until SIGINT/SIGTERM
//	fm-discord-relay once   [-config f]   one pass (shadow/testing)
//	fm-discord-relay emit   [-config f] -kind K [-task T] -id ID text...
//
// It is off unless the config file says "enabled": true. See
// docs/discord-relay.md. The bot token is read only from the environment
// variable named by token_env and is never logged.
package main

import (
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
		fmt.Fprintln(os.Stderr, "usage: fm-discord-relay run|once|emit [-config file]")
		os.Exit(2)
	}
	cmd := os.Args[1]
	if cmd != "run" && cmd != "once" && cmd != "emit" {
		log.Fatalf("fm-discord-relay: unknown command %q", cmd)
	}
	root := os.Getenv("FM_ROOT_OVERRIDE")
	if root == "" {
		exe, err := os.Executable()
		if err != nil {
			log.Fatal(err)
		}
		exe, err = filepath.EvalSymlinks(exe)
		if err != nil {
			log.Fatal(err)
		}
		root = filepath.Dir(filepath.Dir(filepath.Dir(exe)))
	}
	home := os.Getenv("FM_HOME")
	if home == "" {
		home = root
	}
	home, err := filepath.Abs(home)
	if err != nil {
		log.Fatal(err)
	}
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	cfgPath := fs.String("config", filepath.Join(home, "config", "discord-relay.json"), "config file")
	kind := fs.String("kind", "", "emit: decision|review-ready|login|blocker or a routine kind")
	task := fs.String("task", "", "emit: task id")
	id := fs.String("id", "", "emit: required occurrence id")
	_ = fs.Parse(os.Args[2:])

	cfg, err := discordrelay.LoadConfig(*cfgPath)
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	if cmd == "emit" {
		// Hooks must work even when the relay is disabled or down: the event
		// file waits durably for the next pass.
		text := strings.Join(fs.Args(), " ")
		if err := discordrelay.WriteEvent(filepath.Join(cfg.StateDir, "events"), discordrelay.EventIn{ID: *id, Kind: *kind, Task: *task, Text: text}); err != nil {
			log.Fatalf("fm-discord-relay emit: %v", err)
		}
		fmt.Println(*id)
		return
	}
	if !cfg.Enabled {
		log.Fatalf("fm-discord-relay: disabled; set \"enabled\": true in %s to start it", *cfgPath)
	}
	token := os.Getenv(cfg.TokenEnv)
	if token == "" {
		log.Fatalf("fm-discord-relay: environment variable %s is empty", cfg.TokenEnv)
	}
	home, err = filepath.EvalSymlinks(home)
	if err != nil {
		log.Fatalf("fm-discord-relay inbox home: %v", err)
	}
	st, err := discordrelay.OpenStore(cfg.StateDir, discordrelay.Scope{
		ChannelID: cfg.ChannelID, OwnerID: cfg.OwnerID, InboxHome: home,
	})
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	defer st.Close()
	inbox := cfg.InboxCmd
	if !filepath.IsAbs(inbox) {
		inbox, err = filepath.Abs(filepath.Join(root, inbox))
		if err != nil {
			log.Fatal(err)
		}
	}
	r := &discordrelay.Relay{
		Cfg:  cfg,
		Chat: &discordrelay.HTTPChat{Channel: cfg.ChannelID, Token: token},
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
