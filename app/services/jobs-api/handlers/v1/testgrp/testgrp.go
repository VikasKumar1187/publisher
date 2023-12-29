package testgrp

import (
	"context"
	"net/http"

	"github.com/VikasKumar1187/publisher/foundation/web"
)

// Test is our example route.
func Test(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	// Vaidate data
	// Call into the business layer
	// Rteurns errros
	// hanlde OK response

	status := struct {
		Status string
	}{
		Status: "OK",
	}

	return web.Respond(ctx, w, status, http.StatusOK)
}
