package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"littlelearning/server/internal/syncdb"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

type config struct {
	Listen   string `json:"listen"`
	Database string `json:"database"`
	Token    string `json:"token"`
}

func main() {
	configFile := flag.String("config", "config.json", "private config file")
	importFile := flag.String("import", "", "import normalized historical ledgers and exit")
	backup := flag.String("backup", "", "write a consistent SQLite backup and exit")
	flag.Parse()
	raw, err := os.ReadFile(*configFile)
	if err != nil {
		log.Fatal(err)
	}
	var c config
	if err = json.Unmarshal(raw, &c); err != nil {
		log.Fatal(err)
	}
	if c.Listen == "" {
		c.Listen = "127.0.0.1:8787"
	}
	if len(c.Token) < 32 {
		log.Fatal("token must have at least 32 characters")
	}
	db, err := syncdb.Open(c.Database)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if *backup != "" {
		if err = db.Backup(context.Background(), *backup); err != nil {
			log.Fatal(err)
		}
		return
	}
	if *importFile != "" {
		data, err := os.ReadFile(*importFile)
		if err != nil {
			log.Fatal(err)
		}
		var req syncdb.Request
		if err = json.Unmarshal(data, &req); err != nil {
			log.Fatal(err)
		}
		out, err := db.Import(context.Background(), req)
		if err != nil {
			log.Fatal(err)
		}
		json.NewEncoder(os.Stdout).Encode(out.Balances)
		return
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "method", 405)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"ok"}`)
	})
	mux.HandleFunc("/v1/sync", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		if !syncdb.TokenEqual(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "), c.Token) {
			http.Error(w, `{"error":"unauthorized"}`, 401)
			return
		}
		if r.Method != "POST" {
			http.Error(w, `{"error":"method"}`, 405)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 4<<20)
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		var request syncdb.Request
		if err := decoder.Decode(&request); err != nil {
			http.Error(w, `{"error":"invalid request"}`, 400)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
		defer cancel()
		response, err := db.Sync(ctx, request)
		if err != nil {
			response, _ = db.Snapshot(ctx)
			response.Error = err.Error()
			w.WriteHeader(http.StatusConflict)
		}
		json.NewEncoder(w).Encode(response)
	})
	server := &http.Server{Addr: c.Listen, Handler: mux, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: 20 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16384}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		server.Shutdown(shutdown)
	}()
	go func() {
		timer := time.NewTicker(24 * time.Hour)
		defer timer.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-timer.C:
				dir := filepath.Join(filepath.Dir(c.Database), "backups")
				name := filepath.Join(dir, now.Format("20060102-150405")+".db")
				if err := db.Backup(context.Background(), name); err != nil {
					log.Printf("backup failed: %v", err)
				} else {
					matches, _ := filepath.Glob(filepath.Join(dir, "*.db"))
					for len(matches) > 14 {
						os.Remove(matches[0])
						matches = matches[1:]
					}
				}
			}
		}
	}()
	log.Printf("listening on %s", c.Listen)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
