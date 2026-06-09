package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/taiidani/deploy-action/deployer/internal"
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	if err := server(ctx); err != nil {
		log.Fatal(err)
	}
}

// server runs a simple HTTP server listening for GitHub webhook events. It will trigger a deployment when it receives a valid event.
// The server will run until the context is cancelled, at which point it will shut down gracefully.
func server(ctx context.Context) error {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3201"
	}

	mux := http.NewServeMux()
	app := internal.NewServer()
	app.Register(mux)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		BaseContext:       func(_ net.Listener) context.Context { return ctx },
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Start server in a goroutine
	errCh := make(chan error, 1)
	go func() {
		log.Printf("Listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	// Wait for context cancellation or server error
	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		log.Println("Shutting down...")
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		return srv.Shutdown(shutdownCtx)
	}
}
