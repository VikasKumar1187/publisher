package testgrp

import (
	"context"
	"errors"
	"math/rand"
	"net/http"

	"github.com/VikasKumar1187/publisher/foundation/web"
)

// Test is our example route.
func Test(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	// Vaidate data
	// Call into the business layer
	// Rteurns errros
	// hanlde OK response

	if n := rand.Intn(100); n%2 == 0 {
		return errors.New("UNTRUSTED ERROR")
	}

	status := struct {
		Status string
	}{
		Status: "OK",
	}

	return web.Respond(ctx, w, status, http.StatusOK)
}
