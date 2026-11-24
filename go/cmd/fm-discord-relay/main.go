// fm-discord-relay: deterministic, zero-model-token Discord relay for firstmate.
//
//	fm-discord-relay run    loop until SIGINT/SIGTERM
//	fm-discord-relay once   one pass (shadow/testing)
//	fm-discord-relay emit   -kind K [-task T] -id ID text...
//
// It is off unless the config file says "enabled": true. See
// docs/discord-relay.md. The bot token is read from FM_DISCORD_RELAY_TOKEN.
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
		fmt.Fprintln(os.Stderr, "usage: fm-discord-relay run|once|emit")
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
	var event discordrelay.EventIn
	if cmd == "emit" {
		fs.StringVar(&event.Kind, "kind", "", "decision|review-ready|login|blocker or a routine kind")
		fs.StringVar(&event.Task, "task", "", "task id")
		fs.StringVar(&event.ID, "id", "", "required occurrence id")
	}
	_ = fs.Parse(os.Args[2:])
	if cmd != "emit" && fs.NArg() != 0 {
		log.Fatalf("fm-discord-relay %s: unexpected arguments", cmd)
	}
	home, err = filepath.EvalSymlinks(home)
	if err != nil {
		log.Fatalf("fm-discord-relay inbox home: %v", err)
	}
	cfgPath := filepath.Join(home, "config", "discord-relay.json")
	cfg, err := discordrelay.LoadConfig(cfgPath)
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	scope := discordrelay.Scope{ChannelID: cfg.ChannelID, OwnerID: cfg.OwnerID, InboxHome: home}
	if cmd == "emit" {
		event.Text = strings.Join(fs.Args(), " ")
		if err := discordrelay.WriteEvent(cfg.StateDir, scope, event); err != nil {
			log.Fatalf("fm-discord-relay emit: %v", err)
		}
		fmt.Println(event.ID)
		return
	}
	if !cfg.Enabled {
		log.Fatalf("fm-discord-relay: disabled; set \"enabled\": true in %s to start it", cfgPath)
	}
	token := os.Getenv("FM_DISCORD_RELAY_TOKEN")
	if token == "" {
		log.Fatal("fm-discord-relay: environment variable FM_DISCORD_RELAY_TOKEN is empty")
	}
	st, err := discordrelay.OpenStore(cfg.StateDir, scope)
	if err != nil {
		log.Fatalf("fm-discord-relay: %v", err)
	}
	defer st.Close()
	inbox, err := filepath.Abs(filepath.Join(root, "bin", "fm-inbox.sh"))
	if err != nil {
		log.Fatal(err)
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
	t := time.NewTicker(5 * time.Second)
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
