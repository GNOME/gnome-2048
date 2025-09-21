/*
   This file is part of GNOME 2048.

   Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
   Copyright (C) 2016-2020 Arnaud Bonatti <arnaud.bonatti@gmail.com>

   GNOME 2048 is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME 2048 is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME 2048.  If not, see <https://www.gnu.org/licenses/>.
*/

using Games;
using Gtk;

[GtkTemplate (ui = "/org/gnome/TwentyFortyEight/ui/game-window.ui")]
private class GameWindow : Adw.ApplicationWindow
{
    private GLib.Settings _settings;

    [GtkChild] private unowned Adw.HeaderBar    _header_bar;
    [GtkChild] private unowned Label            _score;
    [GtkChild] private unowned MenuButton       _new_game_button;
    [GtkChild] private unowned MenuButton       _hamburger_button;
    private Adw.WindowTitle _window_title;

    [GtkChild] private unowned Game             _game;

    [GtkChild] private unowned Button           _unfullscreen_button;

    public uint8 cli_cols { private get; protected construct; default = 0; }
    public uint8 cli_rows { private get; protected construct; default = 0; }

    construct
    {
        _settings = new GLib.Settings ("org.gnome.TwentyFortyEight");

        _window_title = new Adw.WindowTitle (_("GNOME 2048"), "");
        _header_bar.title_widget = _window_title;

        _hamburger_button.notify ["active"].connect (test_popover_closed);
        _new_game_button.notify ["active"].connect (test_popover_closed);

        _install_ui_action_entries ();

        _init_game ();

        _init_window ();
        _create_scores_dialog ();   // the library forbids to delay the dialog creation

        notify ["has-toplevel-focus"].connect (() => _game.grab_focus ());

        _settings.bind ("window-width", this, "default-width", SettingsBindFlags.DEFAULT);
        _settings.bind ("window-height", this, "default-height", SettingsBindFlags.DEFAULT);
        _settings.bind ("window-maximized", this, "maximized", SettingsBindFlags.DEFAULT);

        close_request.connect(() => {
            _game.save_game ();
            return false;
        });
    }

    internal GameWindow (TwentyFortyEight application, uint8 cols, uint8 rows)
    {
        Object (application: application, visible: true, cli_cols: cols, cli_rows: rows);

        if (cols != 0 && rows != 0)
            new_game_cb ();
        else if (!_game.restore_game (ref _settings))
            new_game_cb ();
    }

    /*\
    * * init
    \*/

    private void _init_game ()
    {
        if (cli_cols != 0 && cli_rows != 0)
        {
            _settings.delay ();
            _settings.set_int ("cols", cli_cols);
            _settings.set_int ("rows", cli_rows);
            _settings.apply ();
            GLib.Settings.sync ();
        }

        _game.notify ["score"].connect (set_score);
        _game.finished.connect ((show_scores) => {
                finished ();

                if (show_scores)
                    _show_best_scores ();

                debug ("finished");
            });
        _game.target_value_reached.connect (target_value_reached_cb);
        _game.undo_enabled.connect (() => { undo_action.set_enabled (true); });
        _game.undo_disabled.connect (() => { undo_action.set_enabled (false); });
    }

    private void _init_window ()
    {
        popover_closed.connect (() => _game.grab_focus ());
        _settings.changed.connect ((settings, key_name) => {
                switch (key_name)
                {
                    case "cols":
                    case "rows":
                        _update_new_game_menu ((uint8) _settings.get_int ("rows"),   // schema ranges rows
                                               (uint8) _settings.get_int ("cols")); // and cols from 1 to 9
                        return;
                    case "allow-undo":
                        _update_hamburger_menu (_settings.get_boolean ("allow-undo"));
                        _game.load_settings (ref _settings);
                        return;
                    case "allow-undo-max":
                    case "animations-speed":
                        _game.load_settings (ref _settings);
                        return;
                }
            });
        _update_new_game_menu ((uint8) _settings.get_int ("rows"),   // schema ranges rows
                               (uint8) _settings.get_int ("cols")); // and cols from 1 to 9
        _update_hamburger_menu (_settings.get_boolean ("allow-undo"));
        _game.load_settings (ref _settings);
    }

    /*\
    * * popovers
    \*/

    internal signal void popover_closed ();

    private void test_popover_closed ()
    {
        if (!has_popover ())
            popover_closed ();
    }

    internal bool has_popover ()
    {
        return _hamburger_button.active || _new_game_button.active;
    }

    /*\
    * * texts
    \*/

    internal void clear_subtitle ()
    {
        _window_title.subtitle = "";
    }

    internal void finished ()
    {
        /* Translators: subtitle of the headerbar, when the user cannot move anymore */
        _window_title.subtitle = _("Game Over");
    }

    internal void set_score (Object game, ParamSpec unused)
    {
        _score.label = ((Game) game).score.to_string ();
    }

    /*\
    * * hamburger menu
    \*/

    internal void _update_hamburger_menu (bool allow_undo)
    {
        GLib.Menu menu = new GLib.Menu ();

        if (allow_undo)
            _append_undo_section (ref menu);
        _append_scores_section (ref menu);
        _append_app_actions_section (ref menu);

        menu.freeze ();
        _hamburger_button.set_menu_model ((MenuModel) menu);
    }

    private static inline void _append_undo_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: entry in the hamburger menu, if the "Allow undo" option is set to true */
        section.append (_("Undo"), "ui.undo");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void _append_scores_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: entry in the hamburger menu; opens a window showing best scores */
        section.append (_("Scores"), "ui.scores");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void _append_app_actions_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: usual menu entry of the hamburger menu */
        section.append (_("Keyboard Shortcuts"), "win.show-help-overlay");

        /* Translators: entry in the hamburger menu */
        section.append (_("About 2048"), "ui.about");

        section.freeze ();
        menu.append_section (null, section);
    }

    /*\
    * * new-game menu
    \*/

    internal void _update_new_game_menu (uint8 rows, uint8 cols)
    {
        GLib.Menu menu = new GLib.Menu ();

        /* Translators: on main window, entry of the menu when clicking on the "New Game" button; to change grid size to 3 × 3 */
        _append_new_game_item (_("3 × 3"),
                    /* rows */ 3,
                    /* cols */ 3,
                           ref menu);

        /* Translators: on main window, entry of the menu when clicking on the "New Game" button; to change grid size to 4 × 4 */
        _append_new_game_item (_("4 × 4"),
                    /* rows */ 4,
                    /* cols */ 4,
                           ref menu);

        /* Translators: on main window, entry of the menu when clicking on the "New Game" button; to change grid size to 5 × 5 */
        _append_new_game_item (_("5 × 5"),
                    /* rows */ 5,
                    /* cols */ 5,
                           ref menu);

        bool is_square = rows == cols;
        bool disallowed_grid = Grid.is_disallowed_grid_size (ref rows, ref cols);
        if (disallowed_grid && !is_square)
            /* Translators: command-line warning displayed if the user manually sets a invalid grid size */
            warning (_("Grids of size 1 by 2 are disallowed."));

        if (!disallowed_grid && (!is_square || (is_square && rows != 4 && rows != 3 && rows != 5)))
            /* Translators: on main window, entry of the menu when clicking on the "New Game" button; appears only if the user has set rows and cols manually */
            _append_new_game_item (_("Custom"), /* rows */ rows, /* cols */ cols, ref menu);

        menu.freeze ();
        _new_game_button.set_menu_model ((MenuModel) menu);
    }
    private static void _append_new_game_item (string label, uint8 rows, uint8 cols, ref GLib.Menu menu)
    {
        Variant variant = new Variant ("(yy)", rows, cols);
        menu.append (label, "ui.new-game-sized(" + variant.print (/* annotate types */ true) + ")");
    }

    /*\
    * * actions
    \*/

    private SimpleAction undo_action;

    private void _install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (_ui_action_entries, this);
        insert_action_group ("ui", action_group);

        undo_action = (SimpleAction) action_group.lookup_action ("undo");
        undo_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] _ui_action_entries =
    {
        { "undo",               undo_cb                     },

        { "new-game",           new_game_cb                 },
        { "new-game-sized",     new_game_sized_cb, "(yy)"   },

        { "toggle-new-game",    toggle_new_game_cb          },
        { "toggle-hamburger",   toggle_hamburger_menu       },

        { "scores",             scores_cb                   },
        { "about",              about_cb                    },

        { "unfullscreen",       unfullscreen                }
    };

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!_settings.get_boolean ("allow-undo"))   // for the keyboard shortcut
            return;

        clear_subtitle ();
        _game.undo ();
        _game.grab_focus ();
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        clear_subtitle ();
        _game.new_game (ref _settings);
        _game.grab_focus ();
    }

    private void new_game_sized_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        uint8 rows, cols;
        ((!) variant).@get ("(yy)", out rows, out cols);
        _settings.delay ();
        _settings.set_int ("rows", rows);
        _settings.set_int ("cols", cols);
        _settings.apply ();

        new_game_cb ();
    }

    private void toggle_new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _new_game_button.active = !_new_game_button.active;
    }

    private void toggle_hamburger_menu (/* SimpleAction action, Variant? variant */)
    {
        _hamburger_button.active = !_hamburger_button.active;
    }

    /*\
    * * congratulations dialog
    \*/

    private inline void target_value_reached_cb (uint target_value)
    {
        if (_settings.get_boolean ("do-congrat"))
        {
            _settings.set_boolean ("do-congrat", false);

            var dialog = new Adw.AlertDialog (
                /* Translators: title of the dialog that appears (with default settings) when you reach 2048 */
                _("Congratulations!"),
                /* Translators: text of the dialog that appears when the user obtains the first 2048 tile in the game; the %u is replaced by the number the user wanted to reach (usually, 2048) */
                _("You have obtained the %u tile for the first time!").replace ("%u", target_value.to_string ())
            );

            dialog.add_responses (
                /* Translators: button in the "Congratulations" dialog that appears (with default settings) when you reach 2048 (with a mnemonic that appears pressing Alt) */
                "new-game", _("_New Game"),
                /* Translators: button in the "Congratulations" dialog that appears (with default settings) when you reach 2048; the player can continue playing after reaching 2048 (with a mnemonic that appears pressing Alt) */
                "continue", _("_Keep Playing"),
                null);

            dialog.set_default_response ("new-game");
            dialog.set_close_response ("continue");

            dialog.response.connect ((response) => {
                if (response == "new-game")
                    new_game_cb ();
            });

            dialog.present (this);
        }
        debug ("target value reached");
    }

    /*\
    * * scores dialog
    \*/

    private Scores.Context _scores_ctx;
    private Scores.Category _grid4_cat;
    private Scores.Category _grid3_cat;
    private Scores.Category _grid5_cat;

    private inline void _create_scores_dialog ()
    {
        /* Translators: combobox entry in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 3 × 3 game and one of other size */
        _grid3_cat = new Scores.Category ("grid3", _("Grid 3 × 3"));

        /* Translators: combobox entry in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 4 × 4 game and one of other size */
        _grid4_cat = new Scores.Category ("grid4", _("Grid 4 × 4"));

        /* Translators: combobox entry in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 5 × 5 game and one of other size */
        _grid5_cat = new Scores.Category ("grid5", _("Grid 5 × 5"));

        /* Translators: label introducing a combobox in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least two games of different size (between 3 × 3, 4 × 4 and 5 × 5) */
        _scores_ctx = new Scores.Context.with_icon_name ("gnome-2048", _("Grid Size:"), this, category_request, Scores.Style.POINTS_GREATER_IS_BETTER, "org.gnome.TwentyFortyEight");
    }
    private inline Scores.Category category_request (string key)
    {
        switch (key)
        {
            case "grid4": return _grid4_cat;
            case "grid3": return _grid3_cat;
            case "grid5": return _grid5_cat;
            default: assert_not_reached ();
        }
    }

    private inline void scores_cb (/* SimpleAction action, Variant? variant */)
    {
        _scores_ctx.run_dialog ();  // TODO open it for current Scores.Category
    }

    private inline void _show_best_scores ()
    {
        uint8 rows = (uint8) _settings.get_int ("rows");  // schema ranges rows
        uint8 cols = (uint8) _settings.get_int ("cols"); // and cols from 1 to 9
        if (rows != cols)
            return;                 // FIXME add categories for non-square grids
        Scores.Category cat;
        switch (rows)
        {
            case 4: cat = _grid4_cat; break;
            case 3: cat = _grid3_cat; break;
            case 5: cat = _grid5_cat; break;
            default: return; // FIXME add categories for non-usual square grids
        }
        _scores_ctx.add_score.begin (_game.score, cat, null, (object, result) => {
                try {
                    _scores_ctx.add_score.end (result);
                } catch (GLib.Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                _scores_ctx.run_dialog ();
                debug ("score added");
            });
    }

    /*\
    * * about dialog
    \*/

    private void about_cb (/* SimpleAction action, Variant? variant */)
    {
        string [] authors = { "Juan R. García Blanco", "Arnaud Bonatti" };
        show_about_dialog (this,
                           /* Translators: about dialog text; the program name */
                           "program-name", _("2048"),
                           "version", VERSION,

                           /* Translators: about dialog text; a introduction to the game */
                           "comments", _("A clone of 2048 for GNOME"),
                           "license-type", License.GPL_3_0,

                           "copyright",
                           /* Translators: text crediting a maintainer, seen in the About dialog */
                           _("Copyright \xc2\xa9 2014-2015 – Juan R. García Blanco") + "\n" +


                           /* Translators: text crediting a maintainer, seen in the About dialog; the %u are replaced with the years of start and end */
                           _("Copyright \xc2\xa9 %u-%u – Arnaud Bonatti").printf (2016, 2020),

                           "wrap-license", true,
                           "authors", authors,
                           /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "org.gnome.TwentyFortyEight",
                           "website", "https://wiki.gnome.org/Apps/2048",
                           /* Translators: about dialog text; label of the website link */
                           "website-label", _("Page on GNOME wiki"),
                           null);
    }
}
