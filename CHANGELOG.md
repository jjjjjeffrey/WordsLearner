# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- Use a fresh dependency-driven timestamp for each comparison history save instead of reusing a single captured startup timestamp.
- Add an integration regression test to verify consecutive `saveToHistory` calls persist distinct `date` values.

