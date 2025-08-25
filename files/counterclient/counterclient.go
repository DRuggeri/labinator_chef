package main

import (
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/CAFxX/balancer"
	"github.com/gorilla/websocket"
)

var wsTarget = "ws://boss.local:8080/loadstats"
var counterTarget = "http://counterserver.default.svc.cluster.local/hit"

// Webslocket settings
var reconnectDuration = 5 * time.Second
var updateDuration = 100 * time.Millisecond

// Client settings
var numConcurrentClients = 20
var numRequestsPerClient = 1000

func main() {
	mux := &sync.Mutex{}
	okCounter := 0
	nokCounter := 0
	log := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))

	if tmp, ok := os.LookupEnv("WS_TARGET"); ok {
		wsTarget = tmp
	}

	if tmp, ok := os.LookupEnv("NUM_CONCURRENT_CLIENTS"); ok {
		if val, err := strconv.Atoi(tmp); err == nil && val > 0 {
			numConcurrentClients = val
		}
	}
	if tmp, ok := os.LookupEnv("NUM_REQUESTS_PER_CLIENT"); ok {
		if val, err := strconv.Atoi(tmp); err == nil && val > 0 {
			numRequestsPerClient = val
		}
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

			c.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf("client:%s", podname)))

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

	for range numConcurrentClients {
		go func(*int, *int) {
			for {
				resolver := &balancer.CachingResolver{
					Resolver: &balancer.SingleflightResolver{
						Resolver: &balancer.TimeoutResolver{
							Resolver: net.DefaultResolver,
							Timeout:  2 * time.Second,
						},
					},
					TTL:    1 * time.Second,
					NegTTL: 250 * time.Millisecond,
				}
				client := &http.Client{
					Timeout: 1 * time.Second,
				}
				client.Transport = balancer.Wrap(http.DefaultTransport, resolver, "ip4")

				for range numRequestsPerClient {
					resp, err := client.Get(counterTarget)
					if err != nil {
						log.Error("error calling counter target", "error", err, "target", counterTarget)
						mux.Lock()
						nokCounter++
						mux.Unlock()
					} else {
						io.Copy(io.Discard, resp.Body)
						resp.Body.Close()
						if resp.StatusCode != http.StatusOK {
							log.Error("non-200 response from counter target", "status", resp.StatusCode, "target", counterTarget)
							mux.Lock()
							nokCounter++
							mux.Unlock()
						} else {
							mux.Lock()
							okCounter++
							mux.Unlock()
						}
					}
				}
			}
		}(&okCounter, &nokCounter)
	}

	slog.Info("Starting counter client", "port", "8080", "target", wsTarget, "service", counterTarget)
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Error("Server failed to start", "error", err)
	}
}
