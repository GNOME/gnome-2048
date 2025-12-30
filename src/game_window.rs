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

use crate::{
    colors::Theme,
    game::Game,
    grid::{Grid, GridSize, SpawnStrategy, restore_size, save_size},
    scores::Scores,
};
use adw::{self, ShortcutsItem, prelude::*, subclass::prelude::*};
use gettextrs::{gettext, pgettext};
use gtk::{gio, glib};
use std::path::PathBuf;

fn save_path() -> PathBuf {
    glib::user_data_dir().join("gnome-2048").join("saved")
}

mod imp {
    use super::*;
    use crate::colors::Theme;
    use std::{cell::Cell, rc::Rc};

    #[derive(glib::Properties)]
    #[properties(wrapper_type = super::GameWindow)]
    pub struct GameWindow {
        #[property(get, set)]
        do_congrat: Cell<bool>,

        #[property(get, set=Self::set_allow_undo)]
        allow_undo: Cell<bool>,

        #[property(get, set, builder(Theme::default()))]
        theme: Cell<Theme>,

        #[property(get, set, builder(SpawnStrategy::default()))]
        spawn_strategy: Cell<SpawnStrategy>,

        header_bar: adw::HeaderBar,
        title: adw::WindowTitle,
        pub(super) new_game_button: gtk::MenuButton,
        pub(super) hamburger_button: gtk::MenuButton,
        score: gtk::Label,

        pub(super) game: Game,

        scores: Rc<Scores>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for GameWindow {
        const NAME: &'static str = "GameWindow";
        type Type = super::GameWindow;
        type ParentType = adw::ApplicationWindow;

        fn class_init(klass: &mut Self::Class) {
            klass.install_action(
                "win.new-game",
                Some(&Option::<GridSize>::static_variant_type()),
                |window, _, size| {
                    window.new_game(size.and_then(Option::<GridSize>::from_variant).flatten())
                },
            );
            klass.install_action("win.undo", None, |window, _, _| window.undo());
            klass.install_action("win.toggle-new-game", None, |window, _, _| {
                let button = &window.imp().new_game_button;
                button.set_active(!button.is_active());
            });
            klass.install_action("win.toggle-hamburger", None, |window, _, _| {
                let button = &window.imp().hamburger_button;
                button.set_active(!button.is_active());
            });
            klass.install_action("win.scores", None, |window, _, _| {
                window.imp().scores.present_dialog(&*window)
            });
            klass.install_action("win.show-keyboard-shortcuts", None, |window, _, _| {
                show_keyboard_shortcuts(window.upcast_ref())
            });
            klass.install_action("win.unfullscreen", None, |window, _, _| {
                window.unfullscreen()
            });
            klass.install_property_action("win.theme", "theme");
            klass.install_property_action("win.spawn-strategy", "spawn-strategy");
        }

        fn new() -> Self {
            Self {
                do_congrat: Cell::new(true),
                allow_undo: Cell::new(false),
                theme: Default::default(),
                spawn_strategy: Default::default(),

                header_bar: Default::default(),
                title: adw::WindowTitle::builder()
                    .title(pgettext("window title", "2048"))
                    .build(),
                new_game_button: gtk::MenuButton::builder()
                    .label(&pgettext(
                        "button in the headerbar (with a mnemonic that appears pressing Alt)",
                        "_New Game",
                    ))
                    .use_underline(true)
                    .valign(gtk::Align::Center)
                    .can_focus(true)
                    .focus_on_click(false)
                    .receives_default(true)
                    .build(),
                hamburger_button: gtk::MenuButton::builder()
                    .halign(gtk::Align::End)
                    .valign(gtk::Align::Center)
                    .focus_on_click(false)
                    .child(
                        &gtk::Image::builder()
                            .icon_name("open-menu-symbolic")
                            .icon_size(gtk::IconSize::Normal)
                            .build(),
                    )
                    .build(),
                score: gtk::Label::builder().can_focus(false).label("0").build(),
                game: Game::default(),
                scores: Scores::new(),
            }
        }
    }

    #[glib::derived_properties]
    impl ObjectImpl for GameWindow {
        fn constructed(&self) {
            self.parent_constructed();
            let window = self.obj();

            window.set_default_width(600);
            window.set_default_height(600);
            window.set_icon_name(Some("org.gnome.TwentyFortyEight"));
            window.set_show_menubar(false);

            let content = gtk::Box::builder()
                .orientation(gtk::Orientation::Vertical)
                .build();
            window.set_content(Some(&content));

            self.header_bar.set_title_widget(Some(&self.title));
            self.hamburger_button.add_css_class("image-button");
            self.header_bar.pack_start(&self.new_game_button);
            self.header_bar.pack_end(&self.hamburger_button);
            self.header_bar.pack_end(&self.score);

            content.append(&self.header_bar);

            let overlay = gtk::Overlay::builder().vexpand(true).build();
            let frame = gtk::AspectFrame::builder().child(&self.game).build();
            overlay.set_child(Some(&frame));

            let unfullscreen_button = gtk::Button::builder()
                .visible(false)
                .halign(gtk::Align::End)
                .valign(gtk::Align::Start)
                .action_name("win.unfullscreen")
                .margin_top(6)
                .margin_bottom(6)
                .margin_start(6)
                .margin_end(6)
                .build();
            unfullscreen_button.add_css_class("image-button");
            unfullscreen_button.add_css_class("flat");
            unfullscreen_button.set_child(Some(
                &gtk::Image::builder()
                    .icon_name("view-restore-symbolic")
                    .icon_size(gtk::IconSize::Normal)
                    .build(),
            ));
            overlay.add_overlay(&unfullscreen_button);

            content.append(&overlay);

            self.hamburger_button.connect_active_notify(glib::clone!(
                #[weak(rename_to=imp)]
                self,
                move |_| imp.popover_closed()
            ));
            self.new_game_button.connect_active_notify(glib::clone!(
                #[weak(rename_to=imp)]
                self,
                move |_| imp.popover_closed()
            ));

            window
                .bind_property("theme", &self.game, "theme")
                .sync_create()
                .build();

            window
                .bind_property("spawn-strategy", &self.game, "spawn-strategy")
                .sync_create()
                .build();

            self.game
                .bind_property("score", &self.score, "label")
                .transform_to(|_, score: u64| Some(score.to_string()))
                .sync_create()
                .build();

            self.new_game_button
                .set_menu_model(Some(&new_game_menu(None)));

            self.game.connect_closure(
                "finished",
                false,
                glib::closure_local!(
                    #[weak(rename_to=imp)]
                    self,
                    move |_: &gtk::Widget, show_scores: bool| {
                        glib::spawn_future_local(async move {
                            imp.finished(show_scores).await;
                        });
                    }
                ),
            );
            self.game.connect_closure(
                "target-value-reached",
                false,
                glib::closure_local!(
                    #[weak(rename_to=imp)]
                    self,
                    move |_: &Game, target_value: u64| {
                        glib::spawn_future_local(async move {
                            imp.target_value_reached(target_value).await;
                        });
                    }
                ),
            );
            window.action_set_enabled("win.undo", false);
            self.game.connect_closure(
                "undo-enabled",
                false,
                glib::closure_local!(
                    #[weak]
                    window,
                    move |_: &gtk::Widget| { window.action_set_enabled("win.undo", true) }
                ),
            );
            self.game.connect_closure(
                "undo-disabled",
                false,
                glib::closure_local!(
                    #[weak]
                    window,
                    move |_: &gtk::Widget| { window.action_set_enabled("win.undo", false) }
                ),
            );

            window.connect_close_request(glib::clone!(
                #[weak(rename_to=imp)]
                self,
                #[upgrade_or]
                glib::Propagation::Proceed,
                move |_| {
                    if let Err(error) = imp.game.grid().save_game(&save_path()) {
                        eprintln!("{error}");
                    }
                    glib::Propagation::Proceed
                }
            ));
        }
    }

    impl WidgetImpl for GameWindow {}
    impl WindowImpl for GameWindow {}
    impl ApplicationWindowImpl for GameWindow {}
    impl AdwApplicationWindowImpl for GameWindow {}

    impl GameWindow {
        fn set_allow_undo(&self, allow_undo: bool) {
            self.allow_undo.set(allow_undo);
            self.hamburger_button
                .set_menu_model(Some(&hamburger_menu(allow_undo)));
        }

        fn popover_closed(&self) {
            if !self.hamburger_button.is_active() && !self.new_game_button.is_active() {
                self.game.grab_focus();
            }
        }

        pub fn clear_subtitle(&self) {
            self.title.set_subtitle("");
        }

        async fn finished(&self, show_scores: bool) {
            self.title.set_subtitle(&pgettext(
                "subtitle of the headerbar, when the user cannot move anymore",
                "Game Over",
            ));
            if show_scores {
                self.scores
                    .show_best_scores(
                        self.game.grid_size(),
                        self.game.score() as i64,
                        &*self.obj(),
                    )
                    .await;
            }
        }

        async fn target_value_reached(&self, target_value: u64) {
            if self.obj().do_congrat() {
                self.obj().set_do_congrat(false);
                if congratulate(self.obj().upcast_ref(), target_value).await {
                    self.obj().new_game(None);
                }
            }
        }
    }
}

glib::wrapper! {
    pub struct GameWindow(ObjectSubclass<imp::GameWindow>)
        @extends adw::ApplicationWindow, gtk::ApplicationWindow, gtk::Window, gtk::Widget,
        @implements gio::ActionMap, gio::ActionGroup, gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::ShortcutManager, gtk::Root, gtk::Native;
}

impl GameWindow {
    pub fn new(app: &adw::Application) -> Self {
        glib::Object::builder().property("application", app).build()
    }

    fn undo(&self) {
        if self.allow_undo() {
            self.imp().clear_subtitle();
            self.imp().game.undo();
            self.imp().game.grab_focus();
        }
    }

    fn new_game(&self, size: Option<GridSize>) {
        self.imp().clear_subtitle();
        self.imp().game.new_game(size);
        self.imp().game.grab_focus();
        self.imp()
            .new_game_button
            .set_menu_model(Some(&new_game_menu(size)));
    }

    pub fn bind_settings(&self, settings: &gio::Settings) {
        self.imp().game.bind_settings(settings);

        settings.bind("do-congrat", self, "do-congrat").build();
        settings.bind("allow-undo", self, "allow-undo").build();
        settings.bind("window-width", self, "default-width").build();
        settings
            .bind("window-height", self, "default-height")
            .build();
        settings.bind("window-maximized", self, "maximized").build();
    }

    pub fn new_game_action(size: Option<GridSize>) -> String {
        format!("win.new-game({})", size.to_variant().print(true))
    }

    pub fn theme_action(theme: Theme) -> String {
        format!("win.theme({})", theme.to_variant().print(true))
    }

    pub fn spawn_strategy_action(spawn_strategy: SpawnStrategy) -> String {
        format!(
            "win.spawn-strategy({})",
            spawn_strategy.to_variant().print(true)
        )
    }
}

pub fn create_window(
    app: &adw::Application,
    settings: &gio::Settings,
    size: Option<GridSize>,
) -> GameWindow {
    let window = GameWindow::new(app);
    window.bind_settings(settings);

    if let Some(size) = size {
        window.new_game(Some(size));
    } else if let Ok(grid) = Grid::restore_game(&save_path()) {
        window.imp().game.set_grid(grid);
    } else {
        let size = restore_size(settings).ok();
        window.new_game(size);
    }

    if let Err(error) = save_size(settings, window.imp().game.grid_size()) {
        eprintln!("{error}")
    }

    window
}

fn hamburger_menu(allow_undo: bool) -> gio::Menu {
    let menu = gio::Menu::new();
    menu.append(
        Some(&pgettext("entry in the hamburger menu", "Undo")),
        Some("win.undo"),
    );
    menu.append_submenu(
        Some(&pgettext("entry in the hamburger menu", "Appearance")),
        &theme_menu(),
    );
    menu.append_submenu(
        Some(&pgettext("entry in the hamburger menu", "Spawn tiles")),
        &spawn_strategy_menu(),
    );
    if allow_undo {
        menu.append_section(None, &undo_section());
    }
    menu.append_section(None, &scores_section());
    menu.append_section(None, &app_actions_section());
    menu.freeze();
    menu
}

fn theme_menu() -> gio::Menu {
    let section = gio::Menu::new();
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; a color theme",
            "Adwaita",
        )),
        Some(&GameWindow::theme_action(Theme::Adwaita)),
    );
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; a color theme",
            "Tango",
        )),
        Some(&GameWindow::theme_action(Theme::Tango)),
    );
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; a color theme",
            "Classic",
        )),
        Some(&GameWindow::theme_action(Theme::Classic)),
    );
    section.freeze();
    section
}

fn spawn_strategy_menu() -> gio::Menu {
    let section = gio::Menu::new();
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; a spawn strategy",
            "Twos only",
        )),
        Some(&GameWindow::spawn_strategy_action(SpawnStrategy::TwosOnly)),
    );
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; a spawn strategy",
            "Classic (twos and fours)",
        )),
        Some(&GameWindow::spawn_strategy_action(
            SpawnStrategy::TwosAndFours,
        )),
    );
    section.freeze();
    section
}

fn undo_section() -> gio::Menu {
    let section = gio::Menu::new();
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu, if the \"Allow undo\" option is set to true",
            "Undo",
        )),
        Some("win.undo"),
    );
    section.freeze();
    section
}

fn scores_section() -> gio::Menu {
    let section = gio::Menu::new();
    section.append(
        Some(&pgettext(
            "entry in the hamburger menu; opens a window showing best scores",
            "Scores",
        )),
        Some("win.scores"),
    );
    section.freeze();
    section
}

fn app_actions_section() -> gio::Menu {
    let section = gio::Menu::new();
    section.append(
        Some(&pgettext("menu entry", "Keyboard Shortcuts")),
        Some("win.show-keyboard-shortcuts"),
    );
    section.append(Some(&pgettext("menu entry", "Help")), Some("app.help"));
    section.append(
        Some(&pgettext("menu entry", "About 2048")),
        Some("app.about"),
    );
    section.freeze();
    section
}

fn new_game_menu(extra_size: Option<GridSize>) -> gio::Menu {
    let menu = gio::Menu::new();

    menu.append(
        Some(&pgettext(
            "on main window, entry of the menu when clicking on the \"New Game\" button",
            "3 × 3",
        )),
        Some(&GameWindow::new_game_action(Some(GridSize::GRID_3_BY_3))),
    );

    menu.append(
        Some(&pgettext(
            "on main window, entry of the menu when clicking on the \"New Game\" button",
            "4 × 4",
        )),
        Some(&GameWindow::new_game_action(Some(GridSize::GRID_4_BY_4))),
    );

    menu.append(
        Some(&pgettext(
            "on main window, entry of the menu when clicking on the \"New Game\" button",
            "5 × 5",
        )),
        Some(&GameWindow::new_game_action(Some(GridSize::GRID_5_BY_5))),
    );

    if let Some(size) = extra_size
        && !size.is_predefined()
    {
        menu.append(
            Some(&pgettext(
                "on main window, entry of the menu when clicking on the \"New Game\" button; appears only if the user has set rows and cols manually",
                "Custom",
            )),
            Some(&GameWindow::new_game_action(Some(size))),
        );
    }

    menu.freeze();
    menu
}

async fn congratulate(parent: &gtk::Widget, target_value: u64) -> bool {
    let dialog = adw::AlertDialog::new(
        Some(&pgettext(
            "title of the dialog that appears (with default settings) when you reach 2048",
            "Congratulations!",
        )),
        Some(
            &pgettext(
                "text of the dialog that appears when the user obtains the first 2048 tile in the game; the %u is replaced by the number the user wanted to reach (usually, 2048)",
                "You have obtained the %u tile for the first time!",
            )
            .replace("%u", &target_value.to_string()),
        ),
    );
    dialog.add_responses(&[
        (
            "new-game",
            &pgettext(
                "button in the \"Congratulations\" dialog that appears (with default settings) when you reach 2048 (with a mnemonic that appears pressing Alt)",
                "_New Game",
            ),
        ),
        (
            "continue",
            &pgettext(
                "button in the \"Congratulations\" dialog that appears (with default settings) when you reach 2048; the player can continue playing after reaching 2048 (with a mnemonic that appears pressing Alt)",
                "_Keep Playing",
            ),
        ),
    ]);
    dialog.set_default_response(Some("new-game"));
    dialog.set_close_response("continue");
    dialog.choose_future(Some(parent)).await == "new-game"
}

fn show_keyboard_shortcuts(parent: &gtk::Widget) {
    let dialog = adw::ShortcutsDialog::new();

    let game_section =
        adw::ShortcutsSection::new(Some(&pgettext("header of the shortcut section", "Game")));
    game_section.add(ShortcutsItem::new(
        &gettext("Play with arrows"),
        "Left Up Right Down",
    ));
    game_section.add(ShortcutsItem::new(&gettext("Play with WASD"), "W A S D"));
    game_section.add(ShortcutsItem::new(
        &gettext("Play with VIM-style bindings"),
        "H J K L",
    ));
    dialog.add(game_section);

    let new_game_section = adw::ShortcutsSection::new(Some(&pgettext(
        "header of the shortcut section",
        "New Game",
    )));
    new_game_section.add(ShortcutsItem::new(
        &gettext("Choose a new game"),
        "<Primary>n",
    ));
    new_game_section.add(ShortcutsItem::new(
        &gettext("Start a new game"),
        "<Shift><Primary>n",
    ));
    dialog.add(new_game_section);

    let generic_section =
        adw::ShortcutsSection::new(Some(&pgettext("header of the shortcut section", "Generic")));
    generic_section.add(ShortcutsItem::new(&gettext("Toggle main menu"), "F10 Menu"));
    generic_section.add(ShortcutsItem::new(&gettext("Help"), "F1 <Primary>F1"));
    generic_section.add(ShortcutsItem::new(
        &gettext("Keyboard shortcuts"),
        "<Primary>question <Shift><Primary>question",
    ));
    generic_section.add(ShortcutsItem::new(
        &gettext("About"),
        "<Shift>F1 <Shift><Primary>F1",
    ));
    generic_section.add(ShortcutsItem::new(&gettext("Quit"), "<Primary>q"));
    dialog.add(generic_section);

    dialog.present(Some(parent));
}
