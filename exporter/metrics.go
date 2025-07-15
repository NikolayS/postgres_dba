package main

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// Metrics holds all Prometheus metrics
type Metrics struct {
	// Backup metrics
	BackupInfo         *prometheus.GaugeVec
	BackupSize         *prometheus.GaugeVec
	BackupDuration     *prometheus.GaugeVec
	BackupAge          *prometheus.GaugeVec
	BackupCount        prometheus.Gauge
	LastBackupTime     prometheus.Gauge
	LastFullBackupTime prometheus.Gauge

	// WAL metrics
	WalInfo         *prometheus.GaugeVec
	WalSize         *prometheus.GaugeVec
	WalAge          *prometheus.GaugeVec
	WalCount        prometheus.Gauge
	LastWalTime     prometheus.Gauge

	// LSN Delta metrics
	LsnDeltaBackup *prometheus.GaugeVec
	LsnDeltaWal    *prometheus.GaugeVec

	// PITR metrics
	PitrWindowSize        prometheus.Gauge
	PitrEarliestTime      prometheus.Gauge
	PitrLatestTime        prometheus.Gauge

	// PostgreSQL state metrics
	PostgresInfo         *prometheus.GaugeVec
	PostgresIsInRecovery prometheus.Gauge
	PostgresTimeline     prometheus.Gauge

	// Error metrics
	CommandErrors  *prometheus.CounterVec
	TotalErrors    prometheus.Counter
	LastError      *prometheus.GaugeVec

	// Exporter metrics
	ExporterInfo          *prometheus.GaugeVec
	ScrapeSuccess         prometheus.Gauge
	ScrapeDuration        prometheus.Histogram
	LastSuccessfulScrape  prometheus.Gauge
}

// NewMetrics creates and registers all Prometheus metrics
func NewMetrics() *Metrics {
	return NewMetricsWithRegistry(prometheus.DefaultRegisterer)
}

// NewMetricsWithRegistry creates and registers all Prometheus metrics with a custom registry
func NewMetricsWithRegistry(registry prometheus.Registerer) *Metrics {
	factory := promauto.With(registry)
	return &Metrics{
		// Backup metrics
		BackupInfo: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_backup_info",
				Help: "Information about WAL-G backups",
			},
			[]string{"backup_name", "backup_type", "hostname", "system_identifier", "is_permanent"},
		),
		BackupSize: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_backup_size_bytes",
				Help: "Size of WAL-G backup in bytes",
			},
			[]string{"backup_name", "backup_type", "size_type"}, // size_type: data, compressed, uncompressed
		),
		BackupDuration: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_backup_duration_seconds",
				Help: "Duration of WAL-G backup in seconds",
			},
			[]string{"backup_name", "backup_type"},
		),
		BackupAge: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_backup_age_seconds",
				Help: "Age of WAL-G backup in seconds",
			},
			[]string{"backup_name", "backup_type"},
		),
		BackupCount: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_backup_count",
				Help: "Total number of WAL-G backups",
			},
		),
		LastBackupTime: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_last_backup_time_seconds",
				Help: "Time since last backup in seconds",
			},
		),
		LastFullBackupTime: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_last_full_backup_time_seconds",
				Help: "Time since last full backup in seconds",
			},
		),

		// WAL metrics
		WalInfo: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_wal_info",
				Help: "Information about WAL files",
			},
			[]string{"wal_file_name", "timeline"},
		),
		WalSize: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_wal_size_bytes",
				Help: "Size of WAL file in bytes",
			},
			[]string{"wal_file_name", "timeline"},
		),
		WalAge: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_wal_age_seconds",
				Help: "Age of WAL file in seconds",
			},
			[]string{"wal_file_name", "timeline"},
		),
		WalCount: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_wal_count",
				Help: "Total number of WAL files",
			},
		),
		LastWalTime: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_last_wal_time_seconds",
				Help: "Time since last WAL push in seconds",
			},
		),

		// LSN Delta metrics
		LsnDeltaBackup: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_lsn_delta_backup_bytes",
				Help: "LSN delta between current position and last backup in bytes",
			},
			[]string{"backup_type"}, // full, incremental
		),
		LsnDeltaWal: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_lsn_delta_wal_bytes",
				Help: "LSN delta between current position and last WAL push in bytes",
			},
			[]string{"timeline"},
		),

		// PITR metrics
		PitrWindowSize: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_pitr_window_size_hours",
				Help: "Size of PITR window in hours",
			},
		),
		PitrEarliestTime: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_pitr_earliest_time_seconds",
				Help: "Earliest possible recovery time as Unix timestamp",
			},
		),
		PitrLatestTime: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_pitr_latest_time_seconds",
				Help: "Latest possible recovery time as Unix timestamp",
			},
		),

		// PostgreSQL state metrics
		PostgresInfo: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_postgres_info",
				Help: "Information about PostgreSQL instance",
			},
			[]string{"server_version", "system_identifier", "current_lsn", "last_wal_received", "last_wal_replayed"},
		),
		PostgresIsInRecovery: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_postgres_is_in_recovery",
				Help: "Whether PostgreSQL is in recovery mode (1 = yes, 0 = no)",
			},
		),
		PostgresTimeline: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_postgres_timeline",
				Help: "Current PostgreSQL timeline",
			},
		),

		// Error metrics
		CommandErrors: factory.NewCounterVec(
			prometheus.CounterOpts{
				Name: "walg_command_errors_total",
				Help: "Total number of errors from WAL-G commands",
			},
			[]string{"command", "error_type"},
		),
		TotalErrors: factory.NewCounter(
			prometheus.CounterOpts{
				Name: "walg_errors_total",
				Help: "Total number of errors",
			},
		),
		LastError: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_last_error_time_seconds",
				Help: "Time of last error as Unix timestamp",
			},
			[]string{"command", "error_type"},
		),

		// Exporter metrics
		ExporterInfo: factory.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "walg_exporter_info",
				Help: "Information about the WAL-G exporter",
			},
			[]string{"version", "commit", "build_date"},
		),
		ScrapeSuccess: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_exporter_scrape_success",
				Help: "Whether the last scrape was successful (1 = yes, 0 = no)",
			},
		),
		ScrapeDuration: factory.NewHistogram(
			prometheus.HistogramOpts{
				Name: "walg_exporter_scrape_duration_seconds",
				Help: "Duration of scrapes in seconds",
				Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 30, 60, 120},
			},
		),
		LastSuccessfulScrape: factory.NewGauge(
			prometheus.GaugeOpts{
				Name: "walg_exporter_last_successful_scrape_time_seconds",
				Help: "Time of last successful scrape as Unix timestamp",
			},
		),
	}
}

// UpdateMetrics updates all metrics based on the provided data
func (m *Metrics) UpdateMetrics(data *MetricsData) {
	// Clear existing metrics
	m.BackupInfo.Reset()
	m.BackupSize.Reset()
	m.BackupDuration.Reset()
	m.BackupAge.Reset()
	m.WalInfo.Reset()
	m.WalSize.Reset()
	m.WalAge.Reset()
	m.LsnDeltaBackup.Reset()
	m.LsnDeltaWal.Reset()
	m.PostgresInfo.Reset()
	m.LastError.Reset()

	// Update backup metrics
	m.BackupCount.Set(float64(len(data.Backups)))
	
	var lastBackupTime, lastFullBackupTime float64
	for _, backup := range data.Backups {
		// Basic backup info
		m.BackupInfo.WithLabelValues(
			backup.BackupName,
			backup.BackupType,
			backup.Hostname,
			backup.SystemIdentifier,
			boolToString(backup.IsPermanent),
		).Set(1)

		// Backup sizes
		m.BackupSize.WithLabelValues(backup.BackupName, backup.BackupType, "data").Set(float64(backup.DataSize))
		m.BackupSize.WithLabelValues(backup.BackupName, backup.BackupType, "compressed").Set(float64(backup.CompressedSize))
		m.BackupSize.WithLabelValues(backup.BackupName, backup.BackupType, "uncompressed").Set(float64(backup.UncompressedSize))

		// Backup duration
		if !backup.StartTime.IsZero() && !backup.FinishTime.IsZero() {
			duration := backup.FinishTime.Sub(backup.StartTime).Seconds()
			m.BackupDuration.WithLabelValues(backup.BackupName, backup.BackupType).Set(duration)
		}

		// Backup age
		if !backup.Time.IsZero() {
			age := data.LastUpdate.Sub(backup.Time).Seconds()
			m.BackupAge.WithLabelValues(backup.BackupName, backup.BackupType).Set(age)
			
			// Track last backup times
			if age < lastBackupTime || lastBackupTime == 0 {
				lastBackupTime = age
			}
			if backup.BackupType == "full" && (age < lastFullBackupTime || lastFullBackupTime == 0) {
				lastFullBackupTime = age
			}
		}
	}

	if lastBackupTime > 0 {
		m.LastBackupTime.Set(lastBackupTime)
	}
	if lastFullBackupTime > 0 {
		m.LastFullBackupTime.Set(lastFullBackupTime)
	}

	// Update WAL metrics
	m.WalCount.Set(float64(len(data.WalFiles)))
	
	var lastWalTime float64
	for _, wal := range data.WalFiles {
		m.WalInfo.WithLabelValues(wal.WalFileName, string(rune(wal.Timeline))).Set(1)
		m.WalSize.WithLabelValues(wal.WalFileName, string(rune(wal.Timeline))).Set(float64(wal.DataSize))
		
		if !wal.FinishTime.IsZero() {
			age := data.LastUpdate.Sub(wal.FinishTime).Seconds()
			m.WalAge.WithLabelValues(wal.WalFileName, string(rune(wal.Timeline))).Set(age)
			
			if age < lastWalTime || lastWalTime == 0 {
				lastWalTime = age
			}
		}
	}

	if lastWalTime > 0 {
		m.LastWalTime.Set(lastWalTime)
	}

	// Update LSN delta metrics
	m.LsnDeltaBackup.WithLabelValues("full").Set(float64(data.LSNDelta.BackupDelta))
	m.LsnDeltaWal.WithLabelValues("current").Set(float64(data.LSNDelta.WalDelta))

	// Update PITR metrics
	m.PitrWindowSize.Set(data.PITRWindow.WindowSizeHours)
	if !data.PITRWindow.EarliestRecoveryTime.IsZero() {
		m.PitrEarliestTime.Set(float64(data.PITRWindow.EarliestRecoveryTime.Unix()))
	}
	if !data.PITRWindow.LatestRecoveryTime.IsZero() {
		m.PitrLatestTime.Set(float64(data.PITRWindow.LatestRecoveryTime.Unix()))
	}

	// Update PostgreSQL metrics
	m.PostgresInfo.WithLabelValues(
		data.PostgresInfo.ServerVersion,
		data.PostgresInfo.SystemIdentifier,
		data.PostgresInfo.CurrentLsn,
		data.PostgresInfo.LastWalReceived,
		data.PostgresInfo.LastWalReplayed,
	).Set(1)

	if data.PostgresInfo.IsInRecovery {
		m.PostgresIsInRecovery.Set(1)
	} else {
		m.PostgresIsInRecovery.Set(0)
	}
	m.PostgresTimeline.Set(float64(data.PostgresInfo.Timeline))

	// Update error metrics
	for command, _ := range data.CommandErrors {
		m.CommandErrors.WithLabelValues(command, "execution_error").Inc()
		m.LastError.WithLabelValues(command, "execution_error").Set(float64(data.LastUpdate.Unix()))
		m.TotalErrors.Inc()
	}

	// Update exporter metrics
	m.ScrapeSuccess.Set(1)
	m.LastSuccessfulScrape.Set(float64(data.LastUpdate.Unix()))
}

// RecordError records an error in the metrics
func (m *Metrics) RecordError(command, errorType string) {
	m.CommandErrors.WithLabelValues(command, errorType).Inc()
	m.TotalErrors.Inc()
	m.LastError.WithLabelValues(command, errorType).SetToCurrentTime()
	m.ScrapeSuccess.Set(0)
}

// boolToString converts boolean to string
func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}