package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

const (
	// PostgreSQL queries
	postgresInfoQuery = `
		SELECT 
			pg_current_wal_lsn() as current_lsn,
			CASE WHEN pg_is_in_recovery() THEN 
				pg_last_wal_receive_lsn() 
			ELSE 
				pg_current_wal_lsn() 
			END as last_wal_received,
			CASE WHEN pg_is_in_recovery() THEN 
				pg_last_wal_replay_lsn() 
			ELSE 
				pg_current_wal_lsn() 
			END as last_wal_replayed,
			pg_is_in_recovery() as is_in_recovery,
			system_identifier::text as system_identifier,
			version() as server_version,
			timeline_id as timeline
		FROM pg_control_system();
	`

	// LSN diff query
	lsnDiffQuery = `
		SELECT 
			pg_wal_lsn_diff($1, $2) as lsn_diff;
	`
)

// Collector collects metrics from wal-g and PostgreSQL
type Collector struct {
	config   *ExporterConfig
	db       *sql.DB
	logger   *logrus.Logger
	metrics  *Metrics
	lastData *MetricsData
}

// NewCollector creates a new collector instance
func NewCollector(config *ExporterConfig, db *sql.DB, logger *logrus.Logger, metrics *Metrics) *Collector {
	return &Collector{
		config:  config,
		db:      db,
		logger:  logger,
		metrics: metrics,
		lastData: &MetricsData{
			CommandErrors: make(map[string]string),
		},
	}
}

// Collect collects all metrics data
func (c *Collector) Collect(ctx context.Context) (*MetricsData, error) {
	start := time.Now()
	defer func() {
		c.metrics.ScrapeDuration.Observe(time.Since(start).Seconds())
	}()

	data := &MetricsData{
		CommandErrors: make(map[string]string),
		LastUpdate:    time.Now(),
	}

	// Collect PostgreSQL info
	if err := c.collectPostgresInfo(ctx, data); err != nil {
		c.logger.WithError(err).Error("Failed to collect PostgreSQL info")
		data.CommandErrors["postgres_info"] = err.Error()
	}

	// Collect backup information
	if err := c.collectBackupInfo(ctx, data); err != nil {
		c.logger.WithError(err).Error("Failed to collect backup info")
		data.CommandErrors["backup_list"] = err.Error()
	}

	// Collect WAL information
	if err := c.collectWalInfo(ctx, data); err != nil {
		c.logger.WithError(err).Error("Failed to collect WAL info")
		data.CommandErrors["wal_info"] = err.Error()
	}

	// Calculate LSN deltas
	if err := c.calculateLSNDeltas(ctx, data); err != nil {
		c.logger.WithError(err).Error("Failed to calculate LSN deltas")
		data.CommandErrors["lsn_delta"] = err.Error()
	}

	// Calculate PITR window
	if err := c.calculatePITRWindow(data); err != nil {
		c.logger.WithError(err).Error("Failed to calculate PITR window")
		data.CommandErrors["pitr_window"] = err.Error()
	}

	c.lastData = data
	return data, nil
}

// collectPostgresInfo collects PostgreSQL state information
func (c *Collector) collectPostgresInfo(ctx context.Context, data *MetricsData) error {
	var info PostgresInfo
	var currentLsn, lastWalReceived, lastWalReplayed sql.NullString
	var systemIdentifier, serverVersion sql.NullString
	var isInRecovery sql.NullBool
	var timeline sql.NullInt64

	err := c.db.QueryRowContext(ctx, postgresInfoQuery).Scan(
		&currentLsn,
		&lastWalReceived,
		&lastWalReplayed,
		&isInRecovery,
		&systemIdentifier,
		&serverVersion,
		&timeline,
	)

	if err != nil {
		return fmt.Errorf("failed to query PostgreSQL info: %w", err)
	}

	info.CurrentLsn = currentLsn.String
	info.LastWalReceived = lastWalReceived.String
	info.LastWalReplayed = lastWalReplayed.String
	info.IsInRecovery = isInRecovery.Bool
	info.SystemIdentifier = systemIdentifier.String
	info.ServerVersion = serverVersion.String
	info.Timeline = int(timeline.Int64)
	info.LastUpdate = time.Now()

	data.PostgresInfo = info
	return nil
}

// collectBackupInfo collects backup information from wal-g
func (c *Collector) collectBackupInfo(ctx context.Context, data *MetricsData) error {
	cmd := exec.CommandContext(ctx, c.config.WalgBinary, "backup-list", "--detail", "--json")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to execute wal-g backup-list: %w", err)
	}

	var backups []BackupInfo
	if err := json.Unmarshal(output, &backups); err != nil {
		// Try to parse as individual JSON objects (some versions output this way)
		if err := c.parseBackupListAlternative(output, &backups); err != nil {
			return fmt.Errorf("failed to parse backup-list output: %w", err)
		}
	}

	// Convert and enrich backup data
	for i := range backups {
		// Parse backup type from backup name or use default
		backups[i].BackupType = c.parseBackupType(backups[i].BackupName)
		
		// Parse LSN values for delta calculations
		if backups[i].StartLsn == "" {
			backups[i].StartLsn = "0/0"
		}
		if backups[i].FinishLsn == "" {
			backups[i].FinishLsn = "0/0"
		}
	}

	data.Backups = backups
	return nil
}

// parseBackupListAlternative parses backup-list output when it's not a JSON array
func (c *Collector) parseBackupListAlternative(output []byte, backups *[]BackupInfo) error {
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var backup BackupInfo
		if err := json.Unmarshal([]byte(line), &backup); err != nil {
			continue // Skip invalid lines
		}
		*backups = append(*backups, backup)
	}
	return nil
}

// collectWalInfo collects WAL information from wal-g
func (c *Collector) collectWalInfo(ctx context.Context, data *MetricsData) error {
	cmd := exec.CommandContext(ctx, c.config.WalgBinary, "wal-show", "--json")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to execute wal-g wal-show: %w", err)
	}

	var walFiles []WalInfo
	if err := json.Unmarshal(output, &walFiles); err != nil {
		// Try to parse as individual JSON objects
		if err := c.parseWalInfoAlternative(output, &walFiles); err != nil {
			return fmt.Errorf("failed to parse wal-show output: %w", err)
		}
	}

	data.WalFiles = walFiles
	return nil
}

// parseWalInfoAlternative parses wal-show output when it's not a JSON array
func (c *Collector) parseWalInfoAlternative(output []byte, walFiles *[]WalInfo) error {
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var wal WalInfo
		if err := json.Unmarshal([]byte(line), &wal); err != nil {
			continue // Skip invalid lines
		}
		*walFiles = append(*walFiles, wal)
	}
	return nil
}

// calculateLSNDeltas calculates LSN deltas between current position and last backup/WAL
func (c *Collector) calculateLSNDeltas(ctx context.Context, data *MetricsData) error {
	if data.PostgresInfo.CurrentLsn == "" {
		return fmt.Errorf("no current LSN available")
	}

	var delta LSNDelta

	// Calculate backup delta (from last backup)
	if len(data.Backups) > 0 {
		lastBackup := data.Backups[len(data.Backups)-1]
		if lastBackup.FinishLsn != "" {
			backupDelta, err := c.calculateLSNDiff(ctx, data.PostgresInfo.CurrentLsn, lastBackup.FinishLsn)
			if err != nil {
				c.logger.WithError(err).Warn("Failed to calculate backup LSN delta")
			} else {
				delta.BackupDelta = backupDelta
			}
		}
	}

	// Calculate WAL delta (from last WAL)
	if len(data.WalFiles) > 0 {
		lastWal := data.WalFiles[len(data.WalFiles)-1]
		if lastWal.FinishLsn != "" {
			walDelta, err := c.calculateLSNDiff(ctx, data.PostgresInfo.CurrentLsn, lastWal.FinishLsn)
			if err != nil {
				c.logger.WithError(err).Warn("Failed to calculate WAL LSN delta")
			} else {
				delta.WalDelta = walDelta
			}
		}
	}

	data.LSNDelta = delta
	return nil
}

// calculateLSNDiff calculates the difference between two LSN values
func (c *Collector) calculateLSNDiff(ctx context.Context, lsn1, lsn2 string) (int64, error) {
	var diff int64
	err := c.db.QueryRowContext(ctx, lsnDiffQuery, lsn1, lsn2).Scan(&diff)
	if err != nil {
		return 0, fmt.Errorf("failed to calculate LSN diff: %w", err)
	}
	return diff, nil
}

// calculatePITRWindow calculates the PITR window based on available backups and WAL files
func (c *Collector) calculatePITRWindow(data *MetricsData) error {
	var window PITRWindow

	// Find earliest recovery time (oldest backup start time)
	if len(data.Backups) > 0 {
		earliest := data.Backups[0].StartTime
		for _, backup := range data.Backups {
			if backup.StartTime.Before(earliest) {
				earliest = backup.StartTime
			}
		}
		window.EarliestRecoveryTime = earliest
	}

	// Find latest recovery time (latest WAL or backup finish time)
	if len(data.WalFiles) > 0 {
		latest := data.WalFiles[0].FinishTime
		for _, wal := range data.WalFiles {
			if wal.FinishTime.After(latest) {
				latest = wal.FinishTime
			}
		}
		window.LatestRecoveryTime = latest
	} else if len(data.Backups) > 0 {
		latest := data.Backups[0].FinishTime
		for _, backup := range data.Backups {
			if backup.FinishTime.After(latest) {
				latest = backup.FinishTime
			}
		}
		window.LatestRecoveryTime = latest
	}

	// Calculate window size
	if !window.EarliestRecoveryTime.IsZero() && !window.LatestRecoveryTime.IsZero() {
		window.WindowSizeHours = window.LatestRecoveryTime.Sub(window.EarliestRecoveryTime).Hours()
	}

	data.PITRWindow = window
	return nil
}

// parseBackupType extracts backup type from backup name
func (c *Collector) parseBackupType(backupName string) string {
	// Common patterns for backup types
	if strings.Contains(backupName, "full") {
		return "full"
	}
	if strings.Contains(backupName, "incr") || strings.Contains(backupName, "delta") {
		return "incremental"
	}
	// Default to full if not specified
	return "full"
}

// parseLSN parses LSN string to numeric value for comparison
func (c *Collector) parseLSN(lsn string) (int64, error) {
	// LSN format: "0/1A2B3C4D"
	parts := strings.Split(lsn, "/")
	if len(parts) != 2 {
		return 0, fmt.Errorf("invalid LSN format: %s", lsn)
	}

	high, err := strconv.ParseInt(parts[0], 16, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse LSN high part: %w", err)
	}

	low, err := strconv.ParseInt(parts[1], 16, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse LSN low part: %w", err)
	}

	return (high << 32) | low, nil
}

// executeWalgCommand executes a wal-g command with timeout
func (c *Collector) executeWalgCommand(ctx context.Context, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, c.config.WalgBinary, args...)
	
	c.logger.WithField("command", fmt.Sprintf("%s %s", c.config.WalgBinary, strings.Join(args, " "))).Debug("Executing wal-g command")
	
	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("command failed with exit code %d: %s", exitError.ExitCode(), string(exitError.Stderr))
		}
		return nil, fmt.Errorf("command execution failed: %w", err)
	}

	return output, nil
}

// validateLSN validates LSN format
func (c *Collector) validateLSN(lsn string) bool {
	// LSN format: "0/1A2B3C4D" or similar
	matched, _ := regexp.MatchString(`^[0-9A-Fa-f]+/[0-9A-Fa-f]+$`, lsn)
	return matched
}