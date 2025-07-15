package main

import (
	"time"
)

// BackupInfo represents information about a backup from wal-g backup-list --detail
type BackupInfo struct {
	BackupName      string    `json:"backup_name"`
	Time            time.Time `json:"time"`
	WalFileName     string    `json:"wal_file_name"`
	StartLsn        string    `json:"start_lsn"`
	FinishLsn       string    `json:"finish_lsn"`
	StartTime       time.Time `json:"start_time"`
	FinishTime      time.Time `json:"finish_time"`
	DatetimeFormat  string    `json:"datetime_format"`
	Hostname        string    `json:"hostname"`
	DataSize        int64     `json:"data_size"`
	CompressedSize  int64     `json:"compressed_size"`
	UncompressedSize int64    `json:"uncompressed_size"`
	IsPermanent     bool      `json:"is_permanent"`
	SystemIdentifier string   `json:"system_identifier"`
	BackupType      string    `json:"backup_type"`
}

// WalInfo represents information about WAL files from wal-g wal-info
type WalInfo struct {
	WalFileName string    `json:"wal_file_name"`
	StartLsn    string    `json:"start_lsn"`
	FinishLsn   string    `json:"finish_lsn"`
	StartTime   time.Time `json:"start_time"`
	FinishTime  time.Time `json:"finish_time"`
	DataSize    int64     `json:"data_size"`
	Timeline    int       `json:"timeline"`
}

// PostgresInfo represents current PostgreSQL state information
type PostgresInfo struct {
	CurrentLsn    string    `json:"current_lsn"`
	LastWalReceived string  `json:"last_wal_received"`
	LastWalReplayed string  `json:"last_wal_replayed"`
	IsInRecovery  bool      `json:"is_in_recovery"`
	SystemIdentifier string `json:"system_identifier"`
	ServerVersion string    `json:"server_version"`
	Timeline      int       `json:"timeline"`
	LastUpdate    time.Time `json:"last_update"`
}

// ExporterConfig represents the configuration for the exporter
type ExporterConfig struct {
	ListenAddress string        `yaml:"listen_address"`
	MetricsPath   string        `yaml:"metrics_path"`
	ScrapeInterval time.Duration `yaml:"scrape_interval"`
	WalgBinary    string        `yaml:"walg_binary"`
	PgConnString  string        `yaml:"pg_conn_string"`
	LogLevel      string        `yaml:"log_level"`
	EnabledMetrics []string     `yaml:"enabled_metrics"`
}

// LSNDelta represents the delta between current LSN and last backup/WAL
type LSNDelta struct {
	BackupDelta int64 `json:"backup_delta"`
	WalDelta    int64 `json:"wal_delta"`
}

// PITRWindow represents the point-in-time recovery window
type PITRWindow struct {
	EarliestRecoveryTime time.Time `json:"earliest_recovery_time"`
	LatestRecoveryTime   time.Time `json:"latest_recovery_time"`
	WindowSizeHours      float64   `json:"window_size_hours"`
}

// MetricsData represents all the metrics data collected
type MetricsData struct {
	Backups       []BackupInfo    `json:"backups"`
	WalFiles      []WalInfo       `json:"wal_files"`
	PostgresInfo  PostgresInfo    `json:"postgres_info"`
	LSNDelta      LSNDelta        `json:"lsn_delta"`
	PITRWindow    PITRWindow      `json:"pitr_window"`
	LastUpdate    time.Time       `json:"last_update"`
	Errors        []string        `json:"errors"`
	CommandErrors map[string]string `json:"command_errors"`
}

// ErrorInfo represents error information with context
type ErrorInfo struct {
	Command   string    `json:"command"`
	Error     string    `json:"error"`
	Timestamp time.Time `json:"timestamp"`
}