# Changelog

All notable changes to postgres_dba will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions workflow for testing PostgreSQL versions 13-17
- Multi-version PostgreSQL testing support in CI/CD pipeline

### Changed
- Migrated CI/CD from CircleCI to GitHub Actions
- Simplified PostgreSQL client installation process for better version compatibility
- Updated test configuration to support multiple PostgreSQL versions

### Fixed
- PostgreSQL client installation issues across different versions
- GitHub Actions PostgreSQL configuration for proper test execution

## [0.1.0] - Initial Release

### Added
- Core database administration functionality
- Basic PostgreSQL connection management
- Initial test suite
- CircleCI configuration for continuous integration