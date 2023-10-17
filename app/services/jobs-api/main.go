package main

import (
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"syscall"

	"github.com/VikasKumar1187/publisher/foundation/logger"
	"go.uber.org/automaxprocs/maxprocs"
	"go.uber.org/zap"
)

var build = "develop"

func main() {

	log, err := logger.New("JOBS-API")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer log.Sync()

	if err := run(log); err != nil {
		log.Errorw("startup", "ERROR", err)
		log.Sync()
		os.Exit(1)
	}

	// if _, err := maxprocs.Set(); err != nil {
	// 	fmt.Println("maxprocs: %w", err)
	// 	os.Exit(1)
	// }

	// g := runtime.GOMAXPROCS(0)
	// log.Printf("starting service CPU Procs testing: build[%s] CPU[%d]", build, g)
	// defer log.Println("service ended")
	// shutdown := make(chan os.Signal, 1)
	// signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)
	// <-shutdown
	// log.Println("stopping service")

}

func run(log *zap.SugaredLogger) error {

	// -------------------------------------------------------------------------
	// GOMAXPROCS

	if _, err := maxprocs.Set(); err != nil {
		log.Errorw("Error", "GOMAXPROCS", err)
		return err
	}

	log.Infow("startup", "GOMAXPROCS", runtime.GOMAXPROCS(0), "BUILD-", build)

	// -------------------------------------------------------------------------

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)

	sig := <-shutdown
	log.Infow("shutdown", "status", "shutdown started", "signal", sig)
	defer log.Infow("shutdown", "status", "shutdown complete", "signal", sig)

	// -------------------------------------------------------------------------
	// Shutdown

	return nil
}
