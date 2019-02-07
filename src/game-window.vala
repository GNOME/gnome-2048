/* Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
 * Copyright (C) 2016-2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of GNOME 2048.
 *
 * GNOME 2048 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME 2048 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME 2048; if not, see <http://www.gnu.org/licenses/>.
 */

using Games;
using Gtk;

[GtkTemplate (ui = "/org/gnome/TwentyFortyEight/ui/game-window.ui")]
private class GameWindow : ApplicationWindow
{
    private GLib.Settings _settings;

    private const int WINDOW_MINIMUM_SIZE_HEIGHT = 600;
    private const int WINDOW_MINIMUM_SIZE_WIDTH = 600;

    private int _window_width;
    private int _window_height;
    private bool _window_maximized;
    private bool _window_is_tiled;

    [GtkChild] private GameHeaderBar    _header_bar;
    [GtkChild] private GtkClutter.Embed _embed;

    private Game _game;
    private bool _game_restored;
    private bool _game_should_init = true;

    construct
    {
        _settings = new GLib.Settings ("org.gnome.TwentyFortyEight");

        install_ui_action_entries ();

        _init_game ();

        _init_window ();
        _create_scores_dialog ();   // the library forbids to delay the dialog creation

        notify ["has-toplevel-focus"].connect (() => _embed.grab_focus ());
        show_all ();
        _init_gesture ();

        _game_restored = _game.restore_game (ref _settings);
        if (!_game_restored)
            new_game_cb ();
        _game_should_init = false;
    }

    /*\
    * * actions
    \*/

    private SimpleAction undo_action;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

        undo_action = (SimpleAction) action_group.lookup_action ("undo");
        undo_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "undo",               undo_cb                     },

        { "new-game",           new_game_cb                 },
        { "toggle-new-game",    toggle_new_game_cb          },
        { "new-game-sized",     new_game_sized_cb, "(ii)"   },

        // hamburger-menu
        { "toggle-hamburger",   toggle_hamburger_menu       },

        { "scores",             scores_cb                   },
        { "about",              about_cb                    }
    };

    /*\
    * * menus
    \*/

    private void toggle_new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.toggle_new_game ();
    }

    private void toggle_hamburger_menu (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.toggle_hamburger_menu ();
    }

    /*\
    * * game
    \*/

    private void _init_game ()
    {
        _game = new Game (ref _settings);
        _game.notify ["score"].connect (_header_bar.set_score);
        _game.finished.connect ((s) => {
                _header_bar.finished ();

                if (!_game_restored)
                    _show_best_scores ();

                debug ("finished");
            });
        _game.target_value_reached.connect (target_value_reached_cb);
        _game.undo_enabled.connect (() => { undo_action.set_enabled (true); });
        _game.undo_disabled.connect (() => { undo_action.set_enabled (false); });
    }

    /*\
    * * window
    \*/

    private void _init_window ()
    {
        set_default_size (_settings.get_int ("window-width"), _settings.get_int ("window-height"));
        if (_settings.get_boolean ("window-maximized"))
            maximize ();

        _header_bar.popover_closed.connect (() => _embed.grab_focus ());
        _settings.changed.connect ((settings, key_name) => {
                switch (key_name)
                {
                    case "cols":
                    case "rows":
                        _header_bar._update_new_game_menu (_settings.get_int ("rows"), _settings.get_int ("cols"));
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
        _header_bar._update_new_game_menu (_settings.get_int ("rows"), _settings.get_int ("cols"));
        _header_bar._update_hamburger_menu (_settings.get_boolean ("allow-undo"));
        _game.load_settings (ref _settings);

        _game.view = _embed.get_stage ();

        set_events (get_events () | Gdk.EventMask.STRUCTURE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);

        Gdk.Geometry geom = Gdk.Geometry ();
        geom.min_height = WINDOW_MINIMUM_SIZE_HEIGHT;
        geom.min_width = WINDOW_MINIMUM_SIZE_WIDTH;
        set_geometry_hints (this, geom, Gdk.WindowHints.MIN_SIZE);
    }

    /*\
    * * undo action
    \*/

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!_settings.get_boolean ("allow-undo"))   // for the keyboard shortcut
            return;

        _header_bar.clear_subtitle ();

        _game.undo ();
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.clear_subtitle ();
        _game_restored = false;

        _game.new_game (ref _settings);

        _embed.grab_focus ();
    }

    private void new_game_sized_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        int rows, cols;
        ((!) variant).@get ("(ii)", out rows, out cols);
        _settings.delay ();
        _settings.set_int ("rows", rows);
        _settings.set_int ("cols", cols);
        _settings.apply ();

        new_game_cb ();
    }

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

                           /* Translators: about dialog text; the main copyright holders */
                           "copyright", _("Copyright \xc2\xa9 2014-2015 – Juan R. García Blanco\nCopyright \xc2\xa9 2016-2019 – Arnaud Bonatti"),
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

    /*\
    * * window management callbacks
    \*/

    private const uint16 KEYCODE_W = 25;
    private const uint16 KEYCODE_A = 38;
    private const uint16 KEYCODE_S = 39;
    private const uint16 KEYCODE_D = 40;

    [GtkCallback]
    private bool key_press_event_cb (Widget widget, Gdk.EventKey event)
    {
        if (_header_bar.has_popover () || (((Window) widget).focus_visible && !_embed.is_focus))
            return false;
        if (_game.cannot_move ())
            return false;

        switch (event.hardware_keycode)
        {
            case KEYCODE_W:     _request_move (MoveRequest.UP);     return true;    // or KEYCODE_UP    = 111;
            case KEYCODE_A:     _request_move (MoveRequest.LEFT);   return true;    // or KEYCODE_LEFT  = 113;
            case KEYCODE_S:     _request_move (MoveRequest.DOWN);   return true;    // or KEYCODE_DOWN  = 116;
            case KEYCODE_D:     _request_move (MoveRequest.RIGHT);  return true;    // or KEYCODE_RIGHT = 114;
        }
        switch (_upper_key (event.keyval))
        {
            case Gdk.Key.Up:    _request_move (MoveRequest.UP);     return true;
            case Gdk.Key.Left:  _request_move (MoveRequest.LEFT);   return true;
            case Gdk.Key.Down:  _request_move (MoveRequest.DOWN);   return true;
            case Gdk.Key.Right: _request_move (MoveRequest.RIGHT);  return true;
        }
        return false;
    }
    private static inline uint _upper_key (uint keyval)
    {
        return (keyval > 255) ? keyval : ((char) keyval).toupper ();
    }

    [GtkCallback]
    private void size_allocate_cb ()
    {
        if (_window_maximized || _window_is_tiled)
            return;
        int? window_width = null;
        int? window_height = null;
        get_size (out window_width, out window_height);
        if (window_width == null || window_height == null)
            return;
        _window_width = (!) window_width;
        _window_height = (!) window_height;
    }

    [GtkCallback]
    private bool state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            _window_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            _window_is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;

        return false;
    }

    internal void before_shutdown ()
    {
        _game.save_game ();

        _settings.delay ();
        _settings.set_int ("window-width", _window_width);
        _settings.set_int ("window-height", _window_height);
        _settings.set_boolean ("window-maximized", _window_maximized);
        _settings.apply ();
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
        _scores_ctx = new Scores.Context ("gnome-2048", _("Grid Size:"), this, category_request, Scores.Style.POINTS_GREATER_IS_BETTER);
    }
    private inline Games.Scores.Category category_request (string key)
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
        int rows = _settings.get_int ("rows");
        int cols = _settings.get_int ("cols");
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

    internal static bool is_disallowed_grid_size (ref int rows, ref int cols)
        requires (rows >= 1)
        requires (rows <= 9)
        requires (cols >= 1)
        requires (cols <= 9)
    {
        return (rows == 1 && cols == 1) || (rows == 1 && cols == 2) || (rows == 2 && cols == 1);
    }

    /*\
    * * gesture
    \*/

    private GestureSwipe gesture;
    private inline void _init_gesture ()
    {
        gesture = new GestureSwipe (_embed); // _window works, but problems with headerbar; the main grid or the aspectframe do as _embed
        gesture.set_propagation_phase (PropagationPhase.CAPTURE);
        gesture.set_button (/* all events */ 0);
        gesture.swipe.connect (_on_swipe);
    }

    private inline void _on_swipe (GestureSwipe gesture, double velocity_x, double velocity_y)
    {
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
                _request_move (MoveRequest.LEFT);
            else if (velocity_x > 10.0)
                _request_move (MoveRequest.RIGHT);
        }
        else if (up_or_down)
        {
            if (velocity_y < -10.0)
                _request_move (MoveRequest.UP);
            else if (velocity_y > 10.0)
                _request_move (MoveRequest.DOWN);
        }
        else
            return;
    }

    /*\
    * * move requests
    \*/

    private void _request_move (MoveRequest request)
    {
        if (_game_should_init)
            return;

        _game_restored = false;
        _game.move (request);
    }
}

private enum MoveRequest {
    UP,
    RIGHT,
    DOWN,
    LEFT;

    internal static string debug_string (MoveRequest request)
    {
        switch (request)
        {
            case UP:    return "move up";
            case RIGHT: return "move right";
            case DOWN:  return "move down";
            case LEFT:  return "move left";
            default:    assert_not_reached ();
        }
    }
}
