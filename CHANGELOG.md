
## [Unreleased]

### Added

- now support `start_link([])` as a special case. This means that if
  you use the default childspec with no args, the server will
  use the initial value for state defined in the `using` block.

- add `start_link` to the top-level Strategy.Dynamic module, so that it
  can itself be supervised.

- Add the `child_spec:` option to Global and Dynamic strategies. If
  truthy, a `child_spec/1` function will be generated. If the value is a
  map, its values will be used to override corresponding values in the
  default.

### Fixed

- returning a reified collection from Hungry.consume trampled on a
  variable.

- The code that looked for the state variable in parameter lists din't
  deal with destructured parameters.

## [v0.2.4] - 2019-01-14

### Added

- `:timeout` is now supported for Strategy.Global (so it is now
   supported by all strategies)

- the `consume/2` function for Hungry workers now takes an `into:`
  option, allowing the results to be returned synchronously into a list
  or map, or asynchronously into a function or a stream.

- `consume/2` takes a `when_done:` option, which nominates a function to
  call when the work in complete. The function is passed the result.
  This is probably most useful when the consume is asynchronous.

### Changed

- Renamed the Strategy.Hungry options from `:default_timeout` and
  `:default_concurrency` to just `:timeout` and `:concurrency` (because
  `:timeout` is the option used by the other strategies)

- Refactored all of the strategy code. I'd forgotten just how
  organically it had grown, and like most organic things it had rotted
  over time.

### Removed

### Fixed

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
[v0.2.4]: https://github.com/pragdave/component/compare/v0.2.3...v0.2.4
[v0.2.3]: https://github.com/pragdave/component/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/pragdave/component/compare/v0.2.1...v0.2.2
