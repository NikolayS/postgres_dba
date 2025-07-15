# WAL-G Prometheus Exporter

A Prometheus exporter for WAL-G (Write-Ahead Logging for PostgreSQL) that monitors backup and WAL file metrics.

## Features

- **Backup Metrics**: Monitor backup count, size, duration, and age
- **WAL Metrics**: Track WAL file count, size, and age
- **LSN Delta Metrics**: Calculate LSN differences between current position and last backup/WAL
- **PITR Metrics**: Monitor Point-in-Time Recovery window
- **PostgreSQL State**: Track PostgreSQL recovery status and timeline
- **Error Tracking**: Monitor command execution errors and failures
- **Health Checks**: Built-in health and readiness endpoints

## Installation

### Prerequisites

- Go 1.21 or later
- PostgreSQL instance with WAL-G configured
- WAL-G binary installed and accessible
- PostgreSQL connection credentials

### Building from Source

```bash
git clone https://github.com/NikolayS/postgres_dba.git
cd postgres_dba/exporter
go build -o wal-g-exporter .
```

## Configuration

### Command Line Flags

```bash
./wal-g-exporter [flags]
```

Available flags:
- `--config`: Path to configuration file (default: "config.yaml")
- `--listen-address`: Address to listen on (default: ":9351")
- `--metrics-path`: Path for metrics endpoint (default: "/metrics")
- `--walg-binary`: Path to wal-g binary (default: "wal-g")
- `--postgres-connection`: PostgreSQL connection string
- `--scrape-interval`: Interval between metric collection (default: 60s)
- `--log-level`: Log level (debug, info, warn, error) (default: "info")
- `--version`: Show version information

### Configuration File

Create a `config.yaml` file (see `config.yaml` example):

```yaml
# Server configuration
listen_address: ":9351"
metrics_path: "/metrics"
scrape_interval: 60s

# WAL-G configuration
walg_binary: "wal-g"

# PostgreSQL connection
postgres_connection: "host=localhost port=5432 user=postgres dbname=postgres sslmode=disable"

# Logging
log_level: "info"
```

## Usage

### Basic Usage

```bash
# Using command line flags
./wal-g-exporter \
  --postgres-connection "host=localhost port=5432 user=postgres dbname=postgres sslmode=disable" \
  --walg-binary "/usr/local/bin/wal-g"

# Using configuration file
./wal-g-exporter --config config.yaml
```

### Docker Usage

```bash
# Build Docker image
docker build -t wal-g-exporter .

# Run with environment variables
docker run -p 9351:9351 \
  -e POSTGRES_CONNECTION="host=postgres port=5432 user=postgres dbname=postgres sslmode=disable" \
  -e WALG_BINARY="/usr/local/bin/wal-g" \
  wal-g-exporter
```

## Endpoints

- `/metrics`: Prometheus metrics endpoint
- `/health`: Health check endpoint
- `/ready`: Readiness check endpoint

## Metrics

### Backup Metrics

- `walg_backup_info`: Information about WAL-G backups
- `walg_backup_size_bytes`: Size of WAL-G backup in bytes
- `walg_backup_duration_seconds`: Duration of WAL-G backup in seconds
- `walg_backup_age_seconds`: Age of WAL-G backup in seconds
- `walg_backup_count`: Total number of WAL-G backups
- `walg_last_backup_time_seconds`: Time since last backup in seconds
- `walg_last_full_backup_time_seconds`: Time since last full backup in seconds

### WAL Metrics

- `walg_wal_info`: Information about WAL files
- `walg_wal_size_bytes`: Size of WAL file in bytes
- `walg_wal_age_seconds`: Age of WAL file in seconds
- `walg_wal_count`: Total number of WAL files
- `walg_last_wal_time_seconds`: Time since last WAL push in seconds

### LSN Delta Metrics

- `walg_lsn_delta_backup_bytes`: LSN delta between current position and last backup
- `walg_lsn_delta_wal_bytes`: LSN delta between current position and last WAL push

### PITR Metrics

- `walg_pitr_window_size_hours`: Size of PITR window in hours
- `walg_pitr_earliest_time_seconds`: Earliest possible recovery time as Unix timestamp
- `walg_pitr_latest_time_seconds`: Latest possible recovery time as Unix timestamp

### PostgreSQL State Metrics

- `walg_postgres_info`: Information about PostgreSQL instance
- `walg_postgres_is_in_recovery`: Whether PostgreSQL is in recovery mode
- `walg_postgres_timeline`: Current PostgreSQL timeline

### Error Metrics

- `walg_command_errors_total`: Total number of errors from WAL-G commands
- `walg_errors_total`: Total number of errors
- `walg_last_error_time_seconds`: Time of last error as Unix timestamp

### Exporter Metrics

- `walg_exporter_info`: Information about the WAL-G exporter
- `walg_exporter_scrape_success`: Whether the last scrape was successful
- `walg_exporter_scrape_duration_seconds`: Duration of scrapes in seconds
- `walg_exporter_last_successful_scrape_time_seconds`: Time of last successful scrape

## Prometheus Configuration

Add the following to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'wal-g-exporter'
    static_configs:
      - targets: ['localhost:9351']
    scrape_interval: 60s
    metrics_path: '/metrics'
```

## Grafana Dashboard

Example Grafana queries:

```promql
# Backup count
walg_backup_count

# Time since last backup
time() - walg_last_backup_time_seconds

# WAL lag in bytes
walg_lsn_delta_wal_bytes

# PITR window size
walg_pitr_window_size_hours

# Error rate
rate(walg_command_errors_total[5m])
```

## Troubleshooting

### Common Issues

1. **WAL-G binary not found**: Ensure WAL-G is installed and accessible via the `--walg-binary` flag
2. **PostgreSQL connection failed**: Check connection string and credentials
3. **Permission denied**: Ensure the exporter has necessary permissions to execute WAL-G commands
4. **Metrics not updating**: Check scrape interval and WAL-G configuration

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
./wal-g-exporter --log-level debug
```

### Health Checks

Check exporter health:

```bash
curl http://localhost:9351/health
curl http://localhost:9351/ready
```

## Testing

Run the test suite:

```bash
go test -v
```

Run integration tests (requires PostgreSQL and WAL-G):

```bash
export POSTGRES_CONNECTION_STRING="host=localhost port=5432 user=postgres dbname=postgres sslmode=disable"
go test -v
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.