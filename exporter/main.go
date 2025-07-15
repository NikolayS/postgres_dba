package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"

	_ "github.com/lib/pq"
)

const (
	defaultConfigFile = "config.yaml"
	defaultLogLevel   = "info"
	
	// Build information (set by linker)
	version   = "dev"
	commit    = "unknown"
	buildDate = "unknown"
)

var (
	configFile = flag.String("config", defaultConfigFile, "Path to configuration file")
	logLevel   = flag.String("log-level", defaultLogLevel, "Log level (debug, info, warn, error)")
	showVersion = flag.Bool("version", false, "Show version information")
	listenAddr = flag.String("listen-address", ":9351", "Address to listen on for HTTP requests")
	metricsPath = flag.String("metrics-path", "/metrics", "Path under which to expose metrics")
	walgBinary = flag.String("walg-binary", "wal-g", "Path to wal-g binary")
	pgConnString = flag.String("postgres-connection", "", "PostgreSQL connection string")
	scrapeInterval = flag.Duration("scrape-interval", 60*time.Second, "Interval between metric collection")
)

// DefaultConfig returns a default configuration
func DefaultConfig() *ExporterConfig {
	return &ExporterConfig{
		ListenAddress:  ":9351",
		MetricsPath:    "/metrics",
		ScrapeInterval: 60 * time.Second,
		WalgBinary:     "wal-g",
		PgConnString:   "",
		LogLevel:       "info",
		EnabledMetrics: []string{
			"backup_info",
			"backup_size",
			"backup_duration", 
			"backup_age",
			"wal_info",
			"wal_size",
			"wal_age",
			"lsn_delta",
			"pitr_window",
			"postgres_info",
			"errors",
		},
	}
}

// LoadConfig loads configuration from file
func LoadConfig(filename string) (*ExporterConfig, error) {
	config := DefaultConfig()
	
	if filename != "" {
		data, err := os.ReadFile(filename)
		if err != nil {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		
		if err := yaml.Unmarshal(data, config); err != nil {
			return nil, fmt.Errorf("failed to parse config file: %w", err)
		}
	}
	
	return config, nil
}

// setupLogger configures the logger
func setupLogger(level string) *logrus.Logger {
	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
	})
	
	logLevel, err := logrus.ParseLevel(level)
	if err != nil {
		logLevel = logrus.InfoLevel
	}
	logger.SetLevel(logLevel)
	
	return logger
}

// connectToPostgres establishes connection to PostgreSQL
func connectToPostgres(connStr string, logger *logrus.Logger) (*sql.DB, error) {
	if connStr == "" {
		return nil, fmt.Errorf("PostgreSQL connection string is required")
	}
	
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to PostgreSQL: %w", err)
	}
	
	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping PostgreSQL: %w", err)
	}
	
	// Configure connection pool
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	
	logger.Info("Connected to PostgreSQL")
	return db, nil
}

// createHTTPServer creates the HTTP server with metrics endpoint
func createHTTPServer(config *ExporterConfig, logger *logrus.Logger) *http.Server {
	mux := http.NewServeMux()
	
	// Metrics endpoint
	mux.Handle(config.MetricsPath, promhttp.Handler())
	
	// Health endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	// Ready endpoint
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Ready"))
	})
	
	// Root endpoint with basic info
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprintf(w, `
		<html>
		<head><title>WAL-G Exporter</title></head>
		<body>
		<h1>WAL-G Prometheus Exporter</h1>
		<p><a href="%s">Metrics</a></p>
		<p><a href="/health">Health</a></p>
		<p><a href="/ready">Ready</a></p>
		<p>Version: %s</p>
		<p>Commit: %s</p>
		<p>Build Date: %s</p>
		</body>
		</html>
		`, config.MetricsPath, version, commit, buildDate)
	})
	
	return &http.Server{
		Addr:    config.ListenAddress,
		Handler: mux,
	}
}

// runCollector runs the metrics collection in a loop
func runCollector(ctx context.Context, collector *Collector, metrics *Metrics, config *ExporterConfig, logger *logrus.Logger) {
	ticker := time.NewTicker(config.ScrapeInterval)
	defer ticker.Stop()
	
	// Initial collection
	collectMetrics(ctx, collector, metrics, logger)
	
	for {
		select {
		case <-ctx.Done():
			logger.Info("Stopping collector")
			return
		case <-ticker.C:
			collectMetrics(ctx, collector, metrics, logger)
		}
	}
}

// collectMetrics performs a single metrics collection
func collectMetrics(ctx context.Context, collector *Collector, metrics *Metrics, logger *logrus.Logger) {
	logger.Debug("Starting metrics collection")
	
	// Create context with timeout
	collectCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	
	data, err := collector.Collect(collectCtx)
	if err != nil {
		logger.WithError(err).Error("Failed to collect metrics")
		metrics.RecordError("collect", "collection_error")
		return
	}
	
	metrics.UpdateMetrics(data)
	logger.WithFields(logrus.Fields{
		"backups":   len(data.Backups),
		"wal_files": len(data.WalFiles),
		"errors":    len(data.CommandErrors),
	}).Info("Metrics collected successfully")
}

func main() {
	flag.Parse()
	
	if *showVersion {
		fmt.Printf("WAL-G Exporter\n")
		fmt.Printf("Version: %s\n", version)
		fmt.Printf("Commit: %s\n", commit)
		fmt.Printf("Build Date: %s\n", buildDate)
		os.Exit(0)
	}
	
	// Setup logger
	logger := setupLogger(*logLevel)
	
	// Load configuration
	config, err := LoadConfig(*configFile)
	if err != nil {
		logger.WithError(err).Fatal("Failed to load configuration")
	}
	
	// Override config with command line flags
	if *listenAddr != ":9351" {
		config.ListenAddress = *listenAddr
	}
	if *metricsPath != "/metrics" {
		config.MetricsPath = *metricsPath
	}
	if *walgBinary != "wal-g" {
		config.WalgBinary = *walgBinary
	}
	if *pgConnString != "" {
		config.PgConnString = *pgConnString
	}
	if *scrapeInterval != 60*time.Second {
		config.ScrapeInterval = *scrapeInterval
	}
	if *logLevel != defaultLogLevel {
		config.LogLevel = *logLevel
	}
	
	logger.WithFields(logrus.Fields{
		"version":         version,
		"commit":          commit,
		"build_date":      buildDate,
		"listen_address":  config.ListenAddress,
		"metrics_path":    config.MetricsPath,
		"walg_binary":     config.WalgBinary,
		"scrape_interval": config.ScrapeInterval,
	}).Info("Starting WAL-G Exporter")
	
	// Connect to PostgreSQL
	db, err := connectToPostgres(config.PgConnString, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to PostgreSQL")
	}
	defer db.Close()
	
	// Create metrics
	metrics := NewMetrics()
	
	// Set exporter info
	metrics.ExporterInfo.WithLabelValues(version, commit, buildDate).Set(1)
	
	// Create collector
	collector := NewCollector(config, db, logger, metrics)
	
	// Create HTTP server
	server := createHTTPServer(config, logger)
	
	// Setup signal handling
	ctx, cancel := context.WithCancel(context.Background())
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	
	// Start collector in background
	go runCollector(ctx, collector, metrics, config, logger)
	
	// Start HTTP server
	go func() {
		logger.WithField("address", config.ListenAddress).Info("Starting HTTP server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("HTTP server failed")
		}
	}()
	
	// Wait for signal
	<-sigChan
	logger.Info("Received shutdown signal")
	
	// Cancel context to stop collector
	cancel()
	
	// Shutdown HTTP server
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()
	
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.WithError(err).Error("Failed to shutdown HTTP server")
	}
	
	logger.Info("Exporter stopped")
}