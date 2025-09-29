# Changelog

All notable changes to postgres_dba will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows PostgreSQL version numbering.

## [18.0] - 2025-01-28

### Added
- GitHub Actions workflow for comprehensive testing across PostgreSQL versions 13-17
- PostgreSQL 17 compatibility with new `pg_stat_checkpointer` view
- Multi-version PostgreSQL testing support in CI/CD pipeline
- Dynamic PL/pgSQL functions for version-aware checkpoint statistics
- Flexible regression testing for cross-version compatibility
- Support for all currently supported PostgreSQL versions (13-17)

### Changed
- **BREAKING**: Now follows PostgreSQL version numbering (jumping from 6.0 to 18.0)
- Migrated CI/CD from CircleCI to GitHub Actions
- Simplified PostgreSQL client installation process for better version compatibility
- Updated test configuration to support multiple PostgreSQL versions
- Improved regression tests to handle storage variations between PostgreSQL versions

### Fixed
- PostgreSQL 17 compatibility issues with `pg_stat_bgwriter` → `pg_stat_checkpointer` migration
- Column mapping for PostgreSQL 17: `checkpoints_timed` → `num_timed`, `checkpoints_req` → `num_requested`, `buffers_checkpoint` → `buffers_written`
- PostgreSQL client installation issues across different versions
- GitHub Actions PostgreSQL configuration for proper test execution
- Query planning errors when using version-specific system views

### Removed
- CircleCI configuration and all related references
- PostgreSQL beta version testing (18-beta, 19-beta) due to Docker image availability

## [6.0] - 2020

### Added
- Core database administration functionality
- Basic PostgreSQL connection management
- Initial test suite
- CircleCI configuration for continuous integration