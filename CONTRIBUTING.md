# Contributing to Pinpin

Thanks for helping out! Bug reports, ideas, docs fixes and code are all welcome.

## Reporting bugs and asking for features

- Search [existing issues](https://github.com/bunkhq/Pinpin/issues) first.
- Use the **Bug report** or **Feature request** template. For bugs, include your macOS version, Mac type (Apple Silicon or Intel) and Pinpin version.
- Permission problems are common. Check [Permissions](docs/PERMISSIONS.md) before filing, especially the section on stale grants.

## Your first contribution

Issues labeled [`good first issue`](https://github.com/bunkhq/Pinpin/labels/good%20first%20issue) are small and self-contained. Comment on one to claim it so nobody duplicates the work.

## Development setup

You need macOS 14 or later and the Swift toolchain (Command Line Tools are enough).

```sh
git clone https://github.com/bunkhq/Pinpin.git
cd Pinpin
./scripts/setup-signing.sh     # once per Mac, keeps permission grants across rebuilds
./scripts/build-app.sh --run   # build and launch build/Pinpin.app
```

See [Development](docs/DEVELOPMENT.md) for signing details and a map of the source files, and [How it works](docs/HOW-IT-WORKS.md) for the architecture.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep each pull request focused on one change.
3. Build and run the app, and test your change by hand. Pinpin has no automated UI tests yet, so describe what you tested in the pull request.
4. Update the docs in `docs/` if you change behavior or settings.
5. Open the pull request and fill in the template.

Release notes are generated from merged pull request titles, so write titles that make sense to users, for example "Add a setting to hide the pin number".

## Code style

- Follow the style of the surrounding code.
- Keep each type in the file that matches its job. The code layout table in [Development](docs/DEVELOPMENT.md#code-layout) lists them.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
