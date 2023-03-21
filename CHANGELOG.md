# Changelog

## Unreleased

## 0.7.4 - 2023-03-22

### Fixed

- Fix FrozenError on Embedded filter.

## 0.7.3 - 2023-02-27

### Fixed

- Fix parser bug that CR is included in some unrelated token.
- Fix wrong signature error on embedded filter.

## 0.7.2 - 2022-01-24

### Fixed

- Fix parser bug at CR+LF empty line.
- Fix typo at internal const name.

## 0.7.1 - 2022-01-18

### Fixed

- Fix error handling on unexpected line ending.
- Fix missing some metadata in gemspec.

## 0.7.0 - 2022-01-04

### Added

- Add `slimi` executable.

### Fixed

- Remove preceding white spaces from HTML comment.
- Fix bug that :generator option was not working.
- Fix bug that Ruby code in nested line can be problem on compilation.

## 0.6.0 - 2022-01-03

### Added

- Support annotate_rendered_view_with_filenames.

### Changed

- Rename expression name from slim to slimi.

### Fixed

- Fix bug at registering handler to ActionView.
- Fix Engine options at RailsTemplateHandler.
- Define missing :generator option at Engine.

## 0.5.1 - 2022-01-02

### Changed

- Wrap slim attrvalue by slimi position expression.

## 0.5.0 - 2022-01-02

### Added

- Add Slimi::Engine.

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
