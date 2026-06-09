package internal

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
)

// workflowRunEvent represents the relevant fields from a GitHub workflow_run webhook payload.
type workflowRunEvent struct {
	Action      string      `json:"action"`
	WorkflowRun workflowRun `json:"workflow_run"`
	Repository  repository  `json:"repository"`
}

type workflowRun struct {
	ID         int64  `json:"id"`
	Conclusion string `json:"conclusion"`
	HeadBranch string `json:"head_branch"`
}

type repository struct {
	FullName      string `json:"full_name"`
	Name          string `json:"name"`
	DefaultBranch string `json:"default_branch"`
}

// hookAction is the HTTP handler for GitHub webhook events. It validates
// the incoming request, parses the event, and triggers a deployment if the event is valid.
func (s *Server) hookAction(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Validate webhook signature
	if s.WebhookSecret != "" {
		signature := r.Header.Get("X-Hub-Signature-256")
		if !validateSignature(body, signature, s.WebhookSecret) {
			log.Println("Webhook signature validation failed")
			http.Error(w, "invalid signature", http.StatusUnauthorized)
			return
		}
	}

	// Check event type
	eventType := r.Header.Get("X-GitHub-Event")
	switch eventType {
	case "ping":
		log.Println("Received ping event")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"message":"pong"}`)
		return
	case "workflow_run":
		// Handle below
	default:
		log.Printf("Ignoring event type: %s", eventType)
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"message":"ignored"}`)
		return
	}

	// Parse workflow_run event
	var event workflowRunEvent
	if err := json.Unmarshal(body, &event); err != nil {
		log.Printf("Failed to parse webhook payload: %v", err)
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	// Only deploy on completed + successful runs on the default branch
	if event.Action != "completed" {
		log.Printf("Ignoring workflow_run action: %s", event.Action)
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"message":"ignored, action=%s"}`, event.Action)
		return
	}

	if event.WorkflowRun.Conclusion != "success" {
		log.Printf("Ignoring workflow_run with conclusion: %s", event.WorkflowRun.Conclusion)
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"message":"ignored, conclusion=%s"}`, event.WorkflowRun.Conclusion)
		return
	}

	if event.WorkflowRun.HeadBranch != event.Repository.DefaultBranch {
		log.Printf("Ignoring workflow_run on non-default branch: %s (default: %s)",
			event.WorkflowRun.HeadBranch, event.Repository.DefaultBranch)
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"message":"ignored, branch=%s"}`, event.WorkflowRun.HeadBranch)
		return
	}

	// Trigger deployment
	service := event.Repository.Name
	runID := event.WorkflowRun.ID

	log.Printf("Deploying service %q from repo %s (run %d)", service, event.Repository.FullName, runID)

	go func() {
		if err := s.Deploy(service, runID); err != nil {
			log.Printf("Deployment failed for %s (run %d): %v", service, runID, err)
		}
	}()

	w.WriteHeader(http.StatusAccepted)
	fmt.Fprintf(w, `{"message":"deployment triggered","service":%q,"run_id":%d}`, service, runID)
}

// validateSignature checks the HMAC-SHA256 signature of the webhook payload.
func validateSignature(payload []byte, signature string, secret string) bool {
	if signature == "" {
		return false
	}

	// Signature format: "sha256=<hex>"
	prefix := "sha256="
	if !strings.HasPrefix(signature, prefix) {
		return false
	}
	sigHex := signature[len(prefix):]

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expected := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(sigHex), []byte(expected))
}
