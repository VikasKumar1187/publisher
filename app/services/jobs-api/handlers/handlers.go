package handlers

import (
	"net/http"
	"os"

	"github.com/VikasKumar1187/publisher/app/services/jobs-api/handlers/v1/testgrp"
	"github.com/VikasKumar1187/publisher/business/web/v1/mid"
	"github.com/VikasKumar1187/publisher/foundation/web"
	"go.uber.org/zap"
)

// APIMuxConfig contains all the mandatory systems required by handlers.
type APIMuxConfig struct {
	Shutdown chan os.Signal
	Log      *zap.SugaredLogger
}

// APIMux constructs a http.Handler with all application routes defined.
func APIMux(cfg APIMuxConfig) *web.App {
	app := web.NewApp(cfg.Shutdown, mid.Logger(cfg.Log))

	app.Handle(http.MethodGet, "/test", testgrp.Test)

	return app
}
