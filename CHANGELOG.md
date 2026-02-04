# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `--json` flag for techdebt scanner (CI/CD integration)
- `--threshold` flag to filter results by severity level
- `--duplicates` flag to enable duplicate code detection
- Comprehensive error handling and exit codes
- `--clean` flag for worktrees script (calls teardown)
- Uncommitted changes detection in worktree setup
- CONTRIBUTING.md with contribution guidelines
- CHANGELOG.md for tracking releases
- GitHub Actions CI workflow (dogfooding techdebt scanner)
- Examples directory with usage patterns

### Changed
- Enhanced README with comparison table and trend context
- Improved worktrees script with better error messages
- Techdebt scanner now has documented exit codes

### Fixed
- Worktree setup handles missing git repositories gracefully
- JSON output properly escapes special characters

## [1.0.0] - 2025-02-02

### Added
- Initial release
- Techdebt scanner with automated code quality detection
- Git worktree management scripts for parallel development
- Claude Code skill integration
- npm package publication
- MIT license

### Features
- File size violation detection
- Dead code detection (commented blocks, unreachable code)
- TODO/FIXME/HACK marker tracking
- TypeScript type safety gap detection
- Dependency health checks (outdated packages, security vulnerabilities)
- Auto-fix mode for safe issues (ESLint, Prettier)
- Git worktree setup with shell alias generation
- Worktree teardown with safety checks

[Unreleased]: https://github.com/unisone/claude-toolkit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/unisone/claude-toolkit/releases/tag/v1.0.0
