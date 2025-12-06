/*
 * Copyright 2025 Andrey Kutejko <andy128k@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 * For more details see the file COPYING.
 */

use crate::config::VERSION;
use adw::{self, prelude::*, subclass::prelude::*};
use gettextrs::{gettext, pgettext};
use gtk::{gio, glib};

const SETTINGS_SCHEMA: &str = "org.gnome.TwentyFortyEight";

mod imp {
    use super::*;
    use crate::{
        about::about,
        cli::play_cli,
        config::PACKAGE,
        game_window::{GameWindow, create_window},
        grid::GridSize,
    };
    use std::{
        cell::{Cell, RefCell},
        error::Error,
        ops::ControlFlow,
    };

    pub struct TwentyFortyEight {
        settings: gio::Settings,
        cli_size: Cell<Option<GridSize>>,
        cli_command: RefCell<Option<String>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TwentyFortyEight {
        const NAME: &'static str = "TwentyFortyEight";
        type Type = super::TwentyFortyEight;
        type ParentType = adw::Application;

        fn new() -> Self {
            Self {
                settings: gio::Settings::new(SETTINGS_SCHEMA),
                cli_size: Default::default(),
                cli_command: Default::default(),
            }
        }
    }

    impl ObjectImpl for TwentyFortyEight {
        fn constructed(&self) {
            self.parent_constructed();
            let app = self.obj();

            app.add_main_option(
                "cli",
                glib::Char::from(b'c'),
                glib::OptionFlags::NONE,
                glib::OptionArg::String,
                &pgettext(
                    "command-line option description",
                    "Play in the terminal (see \"--cli=help\")",
                ),
                Some(&pgettext(
                    "in the command-line options description, text to indicate the user should give a command after '--cli' for playing in the terminal",
                    "COMMAND",
                )),
            );
            app.add_main_option(
                "size",
                glib::Char::from(b's'),
                glib::OptionFlags::NONE,
                glib::OptionArg::String,
                &pgettext(
                    "command-line option description",
                    "Start new game of given size",
                ),
                Some(&pgettext(
                    "in the command-line options description, text to indicate the user should specify a size after '--size'",
                    "SIZE",
                )),
            );
            app.add_main_option(
                "version",
                glib::Char::from(b'v'),
                glib::OptionFlags::NONE,
                glib::OptionArg::None,
                &pgettext(
                    "command-line option description",
                    "Print release version and exit",
                ),
                None,
            );
        }
    }

    impl ApplicationImpl for TwentyFortyEight {
        fn local_command_line(
            &self,
            arguments: &mut gio::subclass::ArgumentList,
        ) -> ControlFlow<glib::ExitCode> {
            if let Some(index) = arguments.iter().position(|a| a == "--cli") {
                arguments.remove(index);

                self.cli_command.replace(Some(String::new()));
                if let Some(cli_command) = arguments.get(index).and_then(|v| v.to_str())
                    && !cli_command.starts_with('-')
                {
                    self.cli_command.replace(Some(cli_command.to_owned()));
                    arguments.remove(index);
                }
            }
            self.parent_local_command_line(arguments)
        }

        fn handle_local_options(&self, options: &glib::VariantDict) -> ControlFlow<glib::ExitCode> {
            if matches!(options.lookup::<bool>("version"), Ok(Some(true))) {
                /* NOTE: Is not translated so can be easily parsed */
                println!("gnome-2048 {VERSION}");
                return ControlFlow::Break(glib::ExitCode::SUCCESS);
            }

            let size = match lookup_size(options) {
                Ok(size) => size,
                Err(error) => {
                    eprintln!("{error}");
                    return ControlFlow::Break(glib::ExitCode::FAILURE);
                }
            };

            self.cli_size.set(size);

            if let Some(cli_command) = self.cli_command.borrow().as_ref() {
                return match play_cli(&cli_command, size, &self.settings) {
                    Ok(()) => ControlFlow::Break(glib::ExitCode::SUCCESS),
                    Err(error) => {
                        eprintln!("{error}");
                        ControlFlow::Break(glib::ExitCode::FAILURE)
                    }
                };
            }

            ControlFlow::Continue(())
        }

        fn startup(&self) {
            self.parent_startup();
            let app = self.obj();

            app.add_action_entries([
                gio::ActionEntry::builder("about")
                    .activate(|obj: &super::TwentyFortyEight, _, _| {
                        about(obj.active_window().and_upcast_ref())
                    })
                    .build(),
                gio::ActionEntry::builder("help")
                    .activate(|obj: &super::TwentyFortyEight, _, _| {
                        display_help(obj.active_window().and_upcast_ref())
                    })
                    .build(),
                gio::ActionEntry::builder("quit")
                    .activate(|obj: &super::TwentyFortyEight, _, _| {
                        if let Some(window) = obj.active_window() {
                            window.destroy();
                        }
                    })
                    .build(),
            ]);

            app.set_accels_for_action("app.about", &["<Shift>F1", "<Shift><Primary>F1"]);
            app.set_accels_for_action("app.quit", &["<Primary>q"]);
            app.set_accels_for_action("win.toggle-new-game", &["<Primary>n"]);
            app.set_accels_for_action(&GameWindow::new_game_action(None), &["<Shift><Primary>n"]);
            app.set_accels_for_action("win.undo", &["<Primary>z"]);
            app.set_accels_for_action(
                "win.show-keyboard-shortcuts",
                &["<Primary>question", "<Shift><Primary>question"],
            );
            app.set_accels_for_action("app.help", &["F1", "<Primary>F1"]);
            app.set_accels_for_action("win.toggle-hamburger", &["F10", "Menu"]);
            app.set_accels_for_action("win.undo", &["<Control>z"]);
        }

        fn activate(&self) {
            self.parent_activate();
            let app = self.obj();

            let window = app.active_window().unwrap_or_else(|| {
                create_window(app.upcast_ref(), &self.settings, self.cli_size.get()).upcast()
            });
            window.present();
        }
    }

    impl GtkApplicationImpl for TwentyFortyEight {}
    impl AdwApplicationImpl for TwentyFortyEight {}

    fn lookup_size(options: &glib::VariantDict) -> Result<Option<GridSize>, Box<dyn Error>> {
        options
            .lookup::<String>("size")?
            .map(|s| parse_size(&s))
            .transpose()
    }

    fn parse_size(size_str: &str) -> Result<GridSize, Box<dyn Error>> {
        let parts: Vec<_> = size_str.split('x').collect();
        if parts.len() != 2 {
            return Err(gettext("Size must be in the form COLSxROWS.").into());
        }
        let cols = parts[0].parse::<u8>()?;
        let rows = parts[1].parse::<u8>()?;
        GridSize::try_new(cols, rows)
    }

    fn display_help(parent_window: Option<&gtk::Window>) {
        gtk::UriLauncher::new(&format!("help:{}", PACKAGE)).launch(
            parent_window,
            gio::Cancellable::NONE,
            |result| {
                if let Err(error) = result {
                    eprintln!("Cannot show a help page: {error}");
                }
            },
        );
    }
}

glib::wrapper! {
    pub struct TwentyFortyEight(ObjectSubclass<imp::TwentyFortyEight>)
        @extends adw::Application, gtk::Application, gio::Application,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl Default for TwentyFortyEight {
    fn default() -> Self {
        glib::Object::builder()
            .property("application-id", "org.gnome.TwentyFortyEight")
            .build()
    }
}
