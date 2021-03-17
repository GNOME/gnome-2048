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
private class GameWindow : ApplicationWindow
{
    private GLib.Settings _settings;

    [GtkChild] private unowned GameHeaderBar    _header_bar;
    [GtkChild] private unowned GtkClutter.Embed _embed;

    [GtkChild] private unowned Button           _unfullscreen_button;

    private Game _game;

    public uint8 cli_cols { private get; protected construct; default = 0; }
    public uint8 cli_rows { private get; protected construct; default = 0; }

    construct
    {
        _settings = new GLib.Settings ("org.gnome.TwentyFortyEight");

        _install_ui_action_entries ();

        _init_game ();

        _init_window ();
        _create_scores_dialog ();   // the library forbids to delay the dialog creation

        notify ["has-toplevel-focus"].connect (() => _embed.grab_focus ());
    }

    internal GameWindow (TwentyFortyEight application, uint8 cols, uint8 rows)
    {
        Object (application: application, visible: true, cli_cols: cols, cli_rows: rows);

        if (cols != 0 && rows != 0)
            new_game_cb ();
        else if (!_game.restore_game (ref _settings))
            new_game_cb ();

        // should be done after game creation, so that you cannot move before
        _init_keyboard ();
        _init_gestures ();
    }

    [GtkCallback]
    private void on_destroy ()
    {
        _game.save_game ();
        _save_window_state (this, ref _settings);
        base.destroy ();
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

        _game = new Game (ref _settings);
        _game.notify ["score"].connect (_header_bar.set_score);
        _game.finished.connect ((show_scores) => {
                _header_bar.finished ();

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
        _init_window_state (this);
        _load_window_state (this, ref _settings);

        _header_bar.popover_closed.connect (() => _embed.grab_focus ());
        _settings.changed.connect ((settings, key_name) => {
                switch (key_name)
                {
                    case "cols":
                    case "rows":
                        _header_bar._update_new_game_menu ((uint8) _settings.get_int ("rows"),   // schema ranges rows
                                                           (uint8) _settings.get_int ("cols")); // and cols from 1 to 9
                        return;
                    case "allow-undo":
                        _header_bar._update_hamburger_menu (_settings.get_boolean ("allow-undo"));
                        _game.load_settings (ref _settings);
                        return;
                    case "allow-undo-max":
                    case "animations-speed":
                        _game.load_settings (ref _settings);
                        return;
                }
            });
        _header_bar._update_new_game_menu ((uint8) _settings.get_int ("rows"),   // schema ranges rows
                                           (uint8) _settings.get_int ("cols")); // and cols from 1 to 9
        _header_bar._update_hamburger_menu (_settings.get_boolean ("allow-undo"));
        _game.load_settings (ref _settings);

        _game.view = _embed.get_stage ();

        set_events (get_events () | Gdk.EventMask.STRUCTURE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
    }

    /*\
    * * window state
    \*/

    private const int WINDOW_MINIMUM_SIZE_HEIGHT = 350;
    private const int WINDOW_MINIMUM_SIZE_WIDTH = 350;

    private int _window_width;
    private int _window_height;
    private bool _window_is_maximized;
    private bool _window_is_fullscreen;
    private bool _window_is_tiled;

    private static void _init_window_state (GameWindow _this)
    {
        _this.window_state_event.connect (state_event_cb);
        _this.size_allocate.connect (size_allocate_cb);

        Gdk.Geometry geom = Gdk.Geometry ();
        geom.min_height = WINDOW_MINIMUM_SIZE_HEIGHT;
        geom.min_width = WINDOW_MINIMUM_SIZE_WIDTH;
        _this.set_geometry_hints (_this, geom, Gdk.WindowHints.MIN_SIZE);
    }

    private static void _load_window_state (GameWindow _this, ref GLib.Settings _settings)
    {
        _this.set_default_size (_settings.get_int ("window-width"),
                                _settings.get_int ("window-height"));

        if (_settings.get_boolean ("window-maximized"))
            _this.maximize ();
    }

    private static void _save_window_state (GameWindow _this, ref GLib.Settings _settings)
    {
        _settings.delay ();
        _settings.set_int       ("window-width",        _this._window_width);
        _settings.set_int       ("window-height",       _this._window_height);
        _settings.set_boolean   ("window-maximized",    _this._window_is_maximized || _this._window_is_fullscreen);
        _settings.apply ();
    }

    private static void size_allocate_cb (Widget widget, Allocation allocation)
    {
        GameWindow _this = (GameWindow) widget;
        if (_this._window_is_maximized || _this._window_is_tiled || _this._window_is_fullscreen)
            return;
        int? window_width = null;
        int? window_height = null;
        _this.get_size (out window_width, out window_height);
        if (window_width == null || window_height == null)
            return;
        _this._window_width = (!) window_width;
        _this._window_height = (!) window_height;
    }

    private const Gdk.WindowState tiled_state = Gdk.WindowState.TILED
                                              | Gdk.WindowState.TOP_TILED
                                              | Gdk.WindowState.BOTTOM_TILED
                                              | Gdk.WindowState.LEFT_TILED
                                              | Gdk.WindowState.RIGHT_TILED;
    private static bool state_event_cb (Widget widget, Gdk.EventWindowState event)
    {
        GameWindow _this = (GameWindow) widget;
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            _this._window_is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        /* fullscreen: saved as maximized */
        bool window_fullscreen = _this._window_is_fullscreen;
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            _this._window_is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
        if (window_fullscreen && !_this._window_is_fullscreen)
            _this._unfullscreen_button.hide ();
        else if (!window_fullscreen && _this._window_is_fullscreen)
            _this._unfullscreen_button.show ();

        /* tiled: not saved, but should not change saved window size */
        if ((event.changed_mask & tiled_state) != 0)
            _this._window_is_tiled = (event.new_window_state & tiled_state) != 0;

        return false;
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

        _header_bar.clear_subtitle ();
        _game.undo ();
        _embed.grab_focus ();
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.clear_subtitle ();
        _game.new_game (ref _settings);
        _embed.grab_focus ();
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
        _header_bar.toggle_new_game ();
    }

    private void toggle_hamburger_menu (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.toggle_hamburger_menu ();
    }

    /*\
    * * keyboard user actions
    \*/

    private EventControllerKey key_controller;      // for keeping in memory

    private const uint16 KEYCODE_W = 25;
    private const uint16 KEYCODE_A = 38;
    private const uint16 KEYCODE_S = 39;
    private const uint16 KEYCODE_D = 40;

    private inline void _init_keyboard ()   // called on construct
    {
        key_controller = new EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
    }

    private static inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        GameWindow _this = (GameWindow) _key_controller.get_widget ();
        if (_this._header_bar.has_popover () || (_this.focus_visible && !_this._embed.is_focus))
            return false;
        if (_this._game.cannot_move ())
            return false;

        switch (keycode)
        {
            case KEYCODE_W:     _this._game.move (MoveRequest.UP);      return true;    // or KEYCODE_UP    = 111;
            case KEYCODE_A:     _this._game.move (MoveRequest.LEFT);    return true;    // or KEYCODE_LEFT  = 113;
            case KEYCODE_S:     _this._game.move (MoveRequest.DOWN);    return true;    // or KEYCODE_DOWN  = 116;
            case KEYCODE_D:     _this._game.move (MoveRequest.RIGHT);   return true;    // or KEYCODE_RIGHT = 114;
        }
        switch (_upper_key (keyval))
        {
            case Gdk.Key.Up:    _this._game.move (MoveRequest.UP);      return true;
            case Gdk.Key.Left:  _this._game.move (MoveRequest.LEFT);    return true;
            case Gdk.Key.Down:  _this._game.move (MoveRequest.DOWN);    return true;
            case Gdk.Key.Right: _this._game.move (MoveRequest.RIGHT);   return true;
        }
        return false;
    }

    private static inline uint _upper_key (uint keyval)
    {
        return (keyval > 255) ? keyval : ((char) keyval).toupper ();
    }

    /*\
    * * gestures
    \*/

    private GestureSwipe gesture_swipe;

    private inline void _init_gestures ()
    {
        gesture_swipe = new GestureSwipe (_embed);  // _window works, but problems with headerbar; the main grid or the aspectframe do as _embed
        gesture_swipe.set_propagation_phase (PropagationPhase.CAPTURE);
        gesture_swipe.set_button (/* all buttons */ 0);
        gesture_swipe.swipe.connect (_on_swipe);
    }

    private inline void _on_swipe (GestureSwipe _gesture_swipe, double velocity_x, double velocity_y)   // do not make static, _gesture_swipe.get_wigdet () is _embed, not the window
    {
        uint button = _gesture_swipe.get_current_button ();
        if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_SECONDARY)
            return;

        if (_game.cannot_move ())
            return;

        double abs_x = velocity_x.abs ();
        double abs_y = velocity_y.abs ();
        if (abs_x * abs_x + abs_y * abs_y < 400.0)
            return;
        bool left_or_right = abs_y * 4.0 < abs_x;
        bool up_or_down = abs_x * 4.0 < abs_y;
        if (left_or_right)
        {
            if (velocity_x < -10.0)
                _game.move (MoveRequest.LEFT);
            else if (velocity_x > 10.0)
                _game.move (MoveRequest.RIGHT);
        }
        else if (up_or_down)
        {
            if (velocity_y < -10.0)
                _game.move (MoveRequest.UP);
            else if (velocity_y > 10.0)
                _game.move (MoveRequest.DOWN);
        }
    }

    /*\
    * * congratulations dialog
    \*/

    private MessageDialog _congrats_dialog;

    private bool _should_create_congrats_dialog = true;
    private inline void _create_congrats_dialog ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/TwentyFortyEight/ui/congrats.ui");

        _congrats_dialog = (MessageDialog) builder.get_object ("congratsdialog");
        _congrats_dialog.set_transient_for (this);

        _congrats_dialog.response.connect ((response_id) => {
                if (response_id == 0)
                    new_game_cb ();
                _congrats_dialog.hide ();
            });
        _congrats_dialog.delete_event.connect ((response_id) => {
                return _congrats_dialog.hide_on_delete ();
            });
    }

    private inline void target_value_reached_cb (uint target_value)
    {
        if (_settings.get_boolean ("do-congrat"))
        {
            if (_should_create_congrats_dialog)
            {
                _create_congrats_dialog ();
                _should_create_congrats_dialog = false;
            }

            /* Translators: text of the dialog that appears when the user obtains the first 2048 tile in the game; the %u is replaced by the number the user wanted to reach (usually, 2048) */
            _congrats_dialog.format_secondary_text (_("You have obtained the %u tile for the first time!"), target_value);
            _congrats_dialog.present ();
            _settings.set_boolean ("do-congrat", false);
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
