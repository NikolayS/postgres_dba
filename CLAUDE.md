# CLAUDE.md

## Engineering Standards

Follow the rules at https://gitlab.com/postgres-ai/rules/-/tree/main/rules — always pull latest before starting work.

## SQL Style

- Lowercase keywords (`select`, `from`, `where` — not `SELECT`, `FROM`, `WHERE`)
- `<>` not `!=`

## CI

GitHub Actions (`test.yml`): runs on push and PRs — tests across PostgreSQL 13, 14, 15, 16, 17, 18, and 19 beta 2.

## Code Review

All changes go through PRs. Before merging, run a REV review (https://gitlab.com/postgres-ai/rev/) and post the report as a PR comment. REV is designed for GitLab but works on GitHub PRs too.

Never merge without explicit approval from the project owner.

## Stack

- Pure SQL reports loaded via `psql` (`\i start.psql`)
- Interactive menu system — user picks a report number
- Works on any Postgres 13+ including managed services (RDS, Cloud SQL, AlloyDB, etc.)
