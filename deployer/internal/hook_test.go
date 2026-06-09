package internal

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func signPayload(payload, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	return "sha256=" + hex.EncodeToString(mac.Sum(nil))
}

func newServer(secret string, deploy DeployFunc) *Server {
	return &Server{
		WebhookSecret: secret,
		DeployPath:    "/mnt/services",
		Deploy:        deploy,
	}
}

func TestHookAction(t *testing.T) {
	const secret = "test-secret"

	validPayload := `{
		"action": "completed",
		"workflow_run": {
			"id": 12345,
			"conclusion": "success",
			"head_branch": "main"
		},
		"repository": {
			"full_name": "taiidani/groceries",
			"name": "groceries",
			"default_branch": "main"
		}
	}`

	tests := []struct {
		name       string
		event      string
		payload    string
		wantStatus int
		wantBody   string
	}{
		{
			name:       "ping event returns pong",
			event:      "ping",
			payload:    `{}`,
			wantStatus: http.StatusOK,
			wantBody:   `{"message":"pong"}`,
		},
		{
			name:       "unknown event type is ignored",
			event:      "push",
			payload:    `{}`,
			wantStatus: http.StatusOK,
			wantBody:   `{"message":"ignored"}`,
		},
		{
			name:       "workflow_run completed success triggers deploy",
			event:      "workflow_run",
			payload:    validPayload,
			wantStatus: http.StatusAccepted,
			wantBody:   `"service":"groceries"`,
		},
		{
			name:  "workflow_run in_progress is ignored",
			event: "workflow_run",
			payload: `{
				"action": "in_progress",
				"workflow_run": {"id": 1, "conclusion": "", "head_branch": "main"},
				"repository": {"full_name": "taiidani/groceries", "name": "groceries", "default_branch": "main"}
			}`,
			wantStatus: http.StatusOK,
			wantBody:   `ignored, action=in_progress`,
		},
		{
			name:  "workflow_run failure is ignored",
			event: "workflow_run",
			payload: `{
				"action": "completed",
				"workflow_run": {"id": 1, "conclusion": "failure", "head_branch": "main"},
				"repository": {"full_name": "taiidani/groceries", "name": "groceries", "default_branch": "main"}
			}`,
			wantStatus: http.StatusOK,
			wantBody:   `ignored, conclusion=failure`,
		},
		{
			name:  "workflow_run on non-default branch is ignored",
			event: "workflow_run",
			payload: `{
				"action": "completed",
				"workflow_run": {"id": 1, "conclusion": "success", "head_branch": "feature"},
				"repository": {"full_name": "taiidani/groceries", "name": "groceries", "default_branch": "main"}
			}`,
			wantStatus: http.StatusOK,
			wantBody:   `ignored, branch=feature`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var mu sync.Mutex
			var deployed []string

			srv := newServer(secret, func(service string, runID int64) error {
				mu.Lock()
				deployed = append(deployed, service)
				mu.Unlock()
				return nil
			})

			req := httptest.NewRequest(http.MethodPost, "/webhook", strings.NewReader(tt.payload))
			req.Header.Set("X-GitHub-Event", tt.event)
			req.Header.Set("X-Hub-Signature-256", signPayload(tt.payload, secret))

			rec := httptest.NewRecorder()
			srv.hookAction(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("status = %d, want %d", rec.Code, tt.wantStatus)
			}

			if !strings.Contains(rec.Body.String(), tt.wantBody) {
				t.Errorf("body = %q, want substring %q", rec.Body.String(), tt.wantBody)
			}
		})
	}
}

func TestValidateSignature(t *testing.T) {
	const secret = "webhook-secret"
	payload := []byte(`{"test": true}`)

	tests := []struct {
		name      string
		signature string
		want      bool
	}{
		{
			name:      "valid signature",
			signature: signPayload(string(payload), secret),
			want:      true,
		},
		{
			name:      "empty signature",
			signature: "",
			want:      false,
		},
		{
			name:      "wrong prefix",
			signature: "sha1=abc123",
			want:      false,
		},
		{
			name:      "tampered signature",
			signature: "sha256=0000000000000000000000000000000000000000000000000000000000000000",
			want:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := validateSignature(payload, tt.signature, secret)
			if got != tt.want {
				t.Errorf("validateSignature() = %v, want %v", got, tt.want)
			}
		})
	}
}
