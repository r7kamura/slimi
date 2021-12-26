# Changelog

## Unreleased

## 0.4.2 - 2021-12-27

### Fixed

- Fix bug on quoted attribute parser.
- Remove trailing line-ending from source line of syntax error message.
- Support multi-line attributes.

## 0.4.1 - 2021-12-26

### Fixed

- Fix bug on parsing Ruby attribute value.
- Fix bug on empty line in text block.

## 0.4.0 - 2021-12-25

### Added

- Support :file option on parser for showing correct file path on syntax error.

### Fixed

- Fix NameError on unknown line indicator.
- Fix bug that default parser options are not used.

## 0.3.0 - 2021-12-24

### Added

- Support Ruby attributes.

### Fixed

- Fix bug about blank line handling.

## 0.2.0 - 2021-12-23

### Added

- Support embedded template.
- Show useful message at syntax error.

## 0.1.1 - 2021-12-21

### Fixed

- Fix bug that Slimi::Interpolation was not working.

## 0.1.0 - 2021-12-20

### Added

- Initial release.
