package internal

import (
	"encoding/json"
	"net/http"
	"os"
)

// DeployFunc is the signature for the function that executes a deployment.
type DeployFunc func(service string, runID int64) error

// Server holds the server configuration loaded from environment variables.
type Server struct {
	// WebhookSecret is the HMAC-SHA256 secret for validating GitHub webhook signatures.
	WebhookSecret string
	// DeployPath is the base path where service directories live (default: /mnt/services).
	DeployPath string
	// Deploy is the function called to execute a deployment. Defaults to mise-based deploy.
	Deploy DeployFunc
}

func NewServer() Server {
	deployPath := os.Getenv("DEPLOY_PATH")
	if deployPath == "" {
		deployPath = "/mnt/services"
	}

	s := Server{
		WebhookSecret: os.Getenv("GITHUB_WEBHOOK_SECRET"),
		DeployPath:    deployPath,
	}
	s.Deploy = s.miseExec
	return s
}

// Register registers the HTTP routes for the web server.
func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	mux.HandleFunc("POST /webhook", s.hookAction)
}
