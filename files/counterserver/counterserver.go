package main

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var wsTarget = "ws://boss.local:8080/loadstats"
var reconnectDuration = 5 * time.Second
var updateDuration = 100 * time.Millisecond

func main() {
	mux := &sync.Mutex{}
	okCounter := 0
	nokCounter := 0 // Should pretty much always be OK?
	log := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))
	if tmp, ok := os.LookupEnv("WS_TARGET"); ok {
		wsTarget = tmp
	}

	podname, _ := os.Hostname()

	go func(*int, *int) {
		for {
			c, _, err := websocket.DefaultDialer.Dial(wsTarget, nil)
			if err != nil {
				log.Error("error connecting to websocket target", "error", err, "target", wsTarget)
				time.Sleep(reconnectDuration)
				continue
			}
			log.Info("Connected to websocket target", "target", wsTarget)
			defer c.Close()

			c.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf("server:%s", podname)))

			for {
				err = c.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf("%d,%d", okCounter, nokCounter)))
				if err != nil {
					log.Error("error writing to websocket", "error", err)
					c.Close()
					break
				}
				time.Sleep(updateDuration)
			}
		}
	}(&okCounter, &nokCounter)

	http.HandleFunc("/hit", func(w http.ResponseWriter, r *http.Request) {
		mux.Lock()
		okCounter++
		mux.Unlock()
		w.WriteHeader(http.StatusOK)
	})
	http.HandleFunc("/count", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, `{ "OK": "%d", "NOK": "%d"}`, okCounter, nokCounter)
	})

	slog.Info("Starting counter server", "port", "8080", "target", wsTarget)
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Error("Server failed to start", "error", err)
	}
}
