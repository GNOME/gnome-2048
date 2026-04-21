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

cargo_env = environment()
cargo_env.set('CARGO_HOME', meson.project_build_root() / 'cargo-home')
cargo_env.prepend('RUSTFLAGS', '-L', (meson.project_build_root() / 'subprojects' / 'libgnome-games-support' / 'games'), '-lgnome-games-support-3', separator : ' ')
cargo_env.set('PACKAGE', meson.project_name())
cargo_env.set('VERSION', meson.project_version())
cargo_env.set('LOCALEDIR', localedir)
cargo_env.set('GETTEXT_PACKAGE', meson.project_name())

cargo_target_dep = custom_target(
  'gnome-2048',
  build_by_default: true,
  build_always_stale: true,
  depends: [libgnome_games_support_dependency],
  output: 'gnome-2048-cargo-target',
  console: true,
  env: cargo_env,
  command: [
    cargo, 'build', cargo_options,
  ]
)

custom_target(
  'gnome-2048-copy-cargo',
  depends: cargo_target_dep,
  build_by_default: true,
  build_always_stale: true,
  install: true,
  install_dir: bindir,
  output: meson.project_name(),
  command: [
    'cp', 'src' / rust_target / meson.project_name(), '@OUTPUT@',
  ]
)

test(
  'cargo-test', cargo,
  env: cargo_env,
  args: ['test', '--no-fail-fast'] + cargo_options,
  depends: [libgnome_games_support_dependency],
  timeout: 180
)
