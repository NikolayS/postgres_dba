package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"github.com/DATA-DOG/go-sqlmock"
)

// MockCollector is a mock implementation for testing
type MockCollector struct {
	mock.Mock
}

func (m *MockCollector) Collect(ctx context.Context) (*MetricsData, error) {
	args := m.Called(ctx)
	return args.Get(0).(*MetricsData), args.Error(1)
}

// CollectorTestSuite is the test suite for collector functionality
type CollectorTestSuite struct {
	suite.Suite
	db       *sql.DB
	sqlMock  sqlmock.Sqlmock
	logger   *logrus.Logger
	metrics  *Metrics
	config   *ExporterConfig
}

func (suite *CollectorTestSuite) SetupTest() {
	// Setup mock database
	db, mock, err := sqlmock.New()
	require.NoError(suite.T(), err)
	
	suite.db = db
	suite.sqlMock = mock
	
	// Setup logger
	suite.logger = logrus.New()
	suite.logger.SetLevel(logrus.DebugLevel)
	
	// Setup metrics with custom registry for testing
	registry := prometheus.NewRegistry()
	suite.metrics = NewMetricsWithRegistry(registry)
	
	// Setup config
	suite.config = &ExporterConfig{
		WalgBinary:     "wal-g",
		PgConnString:   "postgres://test:test@localhost/test",
		ScrapeInterval: 60 * time.Second,
		LogLevel:       "debug",
	}
}

func (suite *CollectorTestSuite) TearDownTest() {
	suite.db.Close()
}

func (suite *CollectorTestSuite) TestCollectPostgresInfo() {
	// Setup expectations
	rows := sqlmock.NewRows([]string{
		"current_lsn", "last_wal_received", "last_wal_replayed", 
		"is_in_recovery", "system_identifier", "server_version", "timeline",
	}).AddRow(
		"0/1A2B3C4D", "0/1A2B3C4D", "0/1A2B3C4D", 
		false, "7123456789012345678", "PostgreSQL 14.9", 1,
	)
	
	suite.sqlMock.ExpectQuery("SELECT.*pg_current_wal_lsn").WillReturnRows(rows)
	
	// Create collector
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	// Test
	data := &MetricsData{CommandErrors: make(map[string]string)}
	err := collector.collectPostgresInfo(context.Background(), data)
	
	// Assertions
	assert.NoError(suite.T(), err)
	assert.Equal(suite.T(), "0/1A2B3C4D", data.PostgresInfo.CurrentLsn)
	assert.Equal(suite.T(), "0/1A2B3C4D", data.PostgresInfo.LastWalReceived)
	assert.Equal(suite.T(), "0/1A2B3C4D", data.PostgresInfo.LastWalReplayed)
	assert.False(suite.T(), data.PostgresInfo.IsInRecovery)
	assert.Equal(suite.T(), "7123456789012345678", data.PostgresInfo.SystemIdentifier)
	assert.Contains(suite.T(), data.PostgresInfo.ServerVersion, "PostgreSQL 14.9")
	assert.Equal(suite.T(), 1, data.PostgresInfo.Timeline)
}

func (suite *CollectorTestSuite) TestCalculateLSNDiff() {
	// Setup expectations
	rows := sqlmock.NewRows([]string{"lsn_diff"}).AddRow(16777216) // 16MB
	suite.sqlMock.ExpectQuery("SELECT.*pg_wal_lsn_diff").WithArgs("0/2000000", "0/1000000").WillReturnRows(rows)
	
	// Create collector
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	// Test
	diff, err := collector.calculateLSNDiff(context.Background(), "0/2000000", "0/1000000")
	
	// Assertions
	assert.NoError(suite.T(), err)
	assert.Equal(suite.T(), int64(16777216), diff)
}

func (suite *CollectorTestSuite) TestParseLSN() {
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	tests := []struct {
		lsn      string
		expected int64
		hasError bool
	}{
		{"0/0", 0, false},
		{"0/1", 1, false},
		{"1/0", 4294967296, false}, // 1 << 32
		{"0/FFFFFFFF", 4294967295, false},
		{"1/FFFFFFFF", 8589934591, false}, // (1 << 32) + 0xFFFFFFFF
		{"invalid", 0, true},
		{"0/invalid", 0, true},
		{"0", 0, true},
	}
	
	for _, test := range tests {
		result, err := collector.parseLSN(test.lsn)
		if test.hasError {
			assert.Error(suite.T(), err, "Expected error for LSN: %s", test.lsn)
		} else {
			assert.NoError(suite.T(), err, "Unexpected error for LSN: %s", test.lsn)
			assert.Equal(suite.T(), test.expected, result, "LSN: %s", test.lsn)
		}
	}
}

func (suite *CollectorTestSuite) TestParseBackupType() {
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	tests := []struct {
		backupName string
		expected   string
	}{
		{"backup_full_20231201", "full"},
		{"backup_incr_20231201", "incremental"},
		{"backup_delta_20231201", "incremental"},
		{"backup_20231201", "full"}, // default
		{"some_random_name", "full"}, // default
	}
	
	for _, test := range tests {
		result := collector.parseBackupType(test.backupName)
		assert.Equal(suite.T(), test.expected, result, "Backup name: %s", test.backupName)
	}
}

func (suite *CollectorTestSuite) TestValidateLSN() {
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	tests := []struct {
		lsn      string
		expected bool
	}{
		{"0/0", true},
		{"0/1A2B3C4D", true},
		{"FFFFFFFF/FFFFFFFF", true},
		{"invalid", false},
		{"0/invalid", false},
		{"0", false},
		{"", false},
	}
	
	for _, test := range tests {
		result := collector.validateLSN(test.lsn)
		assert.Equal(suite.T(), test.expected, result, "LSN: %s", test.lsn)
	}
}

func (suite *CollectorTestSuite) TestCalculatePITRWindow() {
	collector := NewCollector(suite.config, suite.db, suite.logger, suite.metrics)
	
	now := time.Now()
	data := &MetricsData{
		Backups: []BackupInfo{
			{
				BackupName: "backup1",
				StartTime:  now.Add(-2 * time.Hour),
				FinishTime: now.Add(-90 * time.Minute),
			},
			{
				BackupName: "backup2",
				StartTime:  now.Add(-4 * time.Hour),
				FinishTime: now.Add(-210 * time.Minute),
			},
		},
		WalFiles: []WalInfo{
			{
				WalFileName: "wal1",
				StartTime:   now.Add(-30 * time.Minute),
				FinishTime:  now.Add(-15 * time.Minute),
			},
			{
				WalFileName: "wal2",
				StartTime:   now.Add(-60 * time.Minute),
				FinishTime:  now.Add(-45 * time.Minute),
			},
		},
	}
	
	err := collector.calculatePITRWindow(data)
	assert.NoError(suite.T(), err)
	
	// Should use oldest backup start time and latest WAL finish time
	assert.True(suite.T(), data.PITRWindow.EarliestRecoveryTime.Equal(now.Add(-4*time.Hour)))
	assert.True(suite.T(), data.PITRWindow.LatestRecoveryTime.Equal(now.Add(-15*time.Minute)))
	assert.InDelta(suite.T(), 3.75, data.PITRWindow.WindowSizeHours, 0.1) // 3:45
}

func TestCollectorTestSuite(t *testing.T) {
	suite.Run(t, new(CollectorTestSuite))
}

// TestBackupInfoParsing tests parsing of backup list output
func TestBackupInfoParsing(t *testing.T) {
	// Sample backup-list output
	backupListOutput := `[
		{
			"backup_name": "backup_full_20231201_120000",
			"time": "2023-12-01T12:00:00Z",
			"wal_file_name": "000000010000000000000001",
			"start_lsn": "0/1000000",
			"finish_lsn": "0/2000000",
			"start_time": "2023-12-01T12:00:00Z",
			"finish_time": "2023-12-01T12:30:00Z",
			"hostname": "postgres-server",
			"data_size": 1073741824,
			"compressed_size": 536870912,
			"uncompressed_size": 1073741824,
			"is_permanent": false,
			"system_identifier": "7123456789012345678"
		}
	]`
	
	var backups []BackupInfo
	err := json.Unmarshal([]byte(backupListOutput), &backups)
	require.NoError(t, err)
	
	assert.Len(t, backups, 1)
	backup := backups[0]
	
	assert.Equal(t, "backup_full_20231201_120000", backup.BackupName)
	assert.Equal(t, "0/1000000", backup.StartLsn)
	assert.Equal(t, "0/2000000", backup.FinishLsn)
	assert.Equal(t, "postgres-server", backup.Hostname)
	assert.Equal(t, int64(1073741824), backup.DataSize)
	assert.Equal(t, int64(536870912), backup.CompressedSize)
	assert.False(t, backup.IsPermanent)
	assert.Equal(t, "7123456789012345678", backup.SystemIdentifier)
}

// TestWalInfoParsing tests parsing of wal-show output
func TestWalInfoParsing(t *testing.T) {
	// Sample wal-show output
	walShowOutput := `[
		{
			"wal_file_name": "000000010000000000000001",
			"start_lsn": "0/1000000",
			"finish_lsn": "0/2000000",
			"start_time": "2023-12-01T12:00:00Z",
			"finish_time": "2023-12-01T12:00:30Z",
			"data_size": 16777216,
			"timeline": 1
		}
	]`
	
	var walFiles []WalInfo
	err := json.Unmarshal([]byte(walShowOutput), &walFiles)
	require.NoError(t, err)
	
	assert.Len(t, walFiles, 1)
	wal := walFiles[0]
	
	assert.Equal(t, "000000010000000000000001", wal.WalFileName)
	assert.Equal(t, "0/1000000", wal.StartLsn)
	assert.Equal(t, "0/2000000", wal.FinishLsn)
	assert.Equal(t, int64(16777216), wal.DataSize)
	assert.Equal(t, 1, wal.Timeline)
}

// TestCommandExecution tests command execution functionality
func TestCommandExecution(t *testing.T) {
	// This test requires actual wal-g binary or mock, skip if not available
	if _, err := exec.LookPath("wal-g"); err != nil {
		t.Skip("wal-g binary not found, skipping command execution test")
	}
	
	config := &ExporterConfig{
		WalgBinary: "wal-g",
	}
	
	logger := logrus.New()
	logger.SetLevel(logrus.DebugLevel)
	
	metrics := NewMetrics()
	
	// Create a mock database (won't be used for this test)
	db, mock, err := sqlmock.New()
	require.NoError(t, err)
	defer db.Close()
	
	collector := NewCollector(config, db, logger, metrics)
	
	// Test command execution (this might fail if wal-g is not configured)
	output, err := collector.executeWalgCommand(context.Background(), "version")
	if err != nil {
		t.Logf("Expected error for unconfigured wal-g: %v", err)
	} else {
		t.Logf("wal-g version output: %s", string(output))
	}
	
	// Clean up mock expectations
	mock.ExpectationsWereMet()
}

// BenchmarkLSNParsing benchmarks LSN parsing performance
func BenchmarkLSNParsing(b *testing.B) {
	collector := &Collector{}
	lsn := "0/1A2B3C4D"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := collector.parseLSN(lsn)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkLSNValidation benchmarks LSN validation performance
func BenchmarkLSNValidation(b *testing.B) {
	collector := &Collector{}
	lsn := "0/1A2B3C4D"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		collector.validateLSN(lsn)
	}
}

// IntegrationTestCollector is a helper to run integration tests
func IntegrationTestCollector(t *testing.T, pgConnString string) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}
	
	if pgConnString == "" {
		pgConnString = os.Getenv("POSTGRES_CONNECTION_STRING")
		if pgConnString == "" {
			t.Skip("POSTGRES_CONNECTION_STRING not set, skipping integration test")
		}
	}
	
	// Connect to PostgreSQL
	db, err := sql.Open("postgres", pgConnString)
	require.NoError(t, err)
	defer db.Close()
	
	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	err = db.PingContext(ctx)
	require.NoError(t, err)
	
	// Setup collector
	config := &ExporterConfig{
		WalgBinary:     "wal-g",
		PgConnString:   pgConnString,
		ScrapeInterval: 60 * time.Second,
		LogLevel:       "debug",
	}
	
	logger := logrus.New()
	logger.SetLevel(logrus.DebugLevel)
	
	metrics := NewMetrics()
	collector := NewCollector(config, db, logger, metrics)
	
	// Test PostgreSQL info collection
	data := &MetricsData{CommandErrors: make(map[string]string)}
	err = collector.collectPostgresInfo(ctx, data)
	require.NoError(t, err)
	
	assert.NotEmpty(t, data.PostgresInfo.CurrentLsn)
	assert.NotEmpty(t, data.PostgresInfo.SystemIdentifier)
	assert.NotEmpty(t, data.PostgresInfo.ServerVersion)
	
	t.Logf("PostgreSQL info collected: LSN=%s, Version=%s, Timeline=%d",
		data.PostgresInfo.CurrentLsn,
		data.PostgresInfo.ServerVersion,
		data.PostgresInfo.Timeline)
}

// TestIntegrationCollector runs integration tests if environment is set up
func TestIntegrationCollector(t *testing.T) {
	IntegrationTestCollector(t, "")
}