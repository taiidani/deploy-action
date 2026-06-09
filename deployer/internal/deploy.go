package internal

import (
	"bytes"
	"fmt"
	"log"
	"os/exec"
	"strconv"
)

// miseExec executes a deployment for the given service using mise.
// It runs: mise run deploy <service> --filename <service>.tgz --run-id <runID>
func (s *Server) miseExec(service string, runID int64) error {
	filename := service + ".tgz"

	args := []string{
		"run", "deploy", service,
		"--filename", filename,
		"--run-id", strconv.FormatInt(runID, 10),
	}

	log.Printf("Executing: mise %v", args)

	cmd := exec.Command("mise", args...)
	cmd.Dir = s.DeployPath

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		log.Printf("Deploy stdout:\n%s", stdout.String())
		log.Printf("Deploy stderr:\n%s", stderr.String())
		return fmt.Errorf("mise deploy failed: %w", err)
	}

	log.Printf("Deploy succeeded for %s (run %d)", service, runID)
	log.Printf("Deploy output:\n%s", stdout.String())
	return nil
}
