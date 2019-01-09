
## [Unreleased]

## [v0.2.3] - 2019-01-08

### Added

- Support for GenServer callbacks. Previously this was only available
  for Global components. Now there's a new `callbacks` block that can
  inject the callback functions into the correct GenServer worker
  regardless of the strategy.

- the README now has a table of contents


## [v0.2.2] - 2019-01-07

### Added

- support for default parameters in `one_way` and `two_way` declarations

### Changed

### Removed

### Fixed

- fixes issue #4



[Unreleased]: https://github.com/pragdave/component/compare/v0.2.2...HEAD
[v0.2.3]: https://github.com/pragdave/component/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/pragdave/component/compare/v0.2.1...v0.2.2
