conf_data = configuration_data()
conf_data.set_quoted('PACKAGE',         '@0@'.format(meson.project_name()))
conf_data.set_quoted('VERSION',         '@0@'.format(meson.project_version()))
conf_data.set_quoted('LOCALEDIR',       '@0@'.format(localedir))
conf_data.set_quoted('GETTEXT_PACKAGE',	'@0@'.format(meson.project_name()))

config_rs = configure_file(
  input: 'config.rs.in',
  output: 'config.rs',
  configuration: conf_data
)
run_command(
  'cp',
  meson.project_build_root() / 'src' / 'config.rs',
  meson.project_source_root() / 'src' / 'config.rs',
  check: true
)

cargo_options = [
  '--manifest-path', meson.project_source_root() / 'Cargo.toml',
  '--target-dir', meson.project_build_root() / 'src',
]

if profile == 'debug'
  rust_target = 'debug'
  message('Building in debug mode')
else
  cargo_options += [ '--release' ]
  rust_target = 'release'
  message('Building in release mode')
endif

cargo_env = [
  'CARGO_HOME=' + meson.project_build_root() / 'cargo-home',
  'RUSTFLAGS=-L ' + (meson.project_build_root() / 'subprojects' / 'libgnome-games-support' / 'games')
        + ' -lgnome-games-support-3'
]

custom_target(
  'gnome-2048',
  build_by_default: true,
  build_always_stale: true,
  input: [config_rs],
  output: meson.project_name(),
  console: true,
  install: true,
  install_dir: bindir,
  command: [
    'env',
    cargo_env,
    cargo, 'build', cargo_options,
    '&&',
    'cp', 'src' / rust_target / meson.project_name(), '@OUTPUT@',
  ]
)

test(
  'cargo-test', cargo,
  env: cargo_env,
  args: ['test', '--no-fail-fast'] + cargo_options,
  # depends: [libgnome_games_support_dependency],
  timeout: 180
)