/* Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
 * Copyright (C) 2016 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

public class Application : Gtk.Application
{
    /* settings */
    private GLib.Settings _settings;

    private int _window_width;
    private int _window_height;
    private bool _window_maximized;

    private int WINDOW_MINIMUM_SIZE_HEIGHT = 600;
    private int WINDOW_MINIMUM_SIZE_WIDTH = 600;

    /* private widgets */
    private Window _window;
    private HeaderBar _header_bar;
    private Label _score;
    private MenuButton _new_game_button;
    private MenuButton _hamburger_button;

    private GtkClutter.Embed embed;

    private bool _game_restored;

    private Game _game;

    /* actions */
    private const GLib.ActionEntry[] action_entries =
    {
        { "undo",               undo_cb                     },

        { "new-game",           new_game_cb                 },
        { "toggle-new-game",    toggle_new_game_cb          },
        { "new-game-sized",     new_game_sized_cb, "(ii)"   },
        { "animations-speed",   _animations_speed, "s"      },  // no way to make it take a double

        { "quit",               quit_cb                     },

        // hamburger-menu
        { "toggle-hamburger",   toggle_hamburger_menu       },

        { "scores",             scores_cb                   },
        { "preferences",        preferences_cb              },
        { "about",              about_cb                    },
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        OptionContext context = new OptionContext ("");

        context.add_group (get_option_group (true));
        context.add_group (Clutter.get_option_group_without_init ());

        try {
            context.parse (ref args);
        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name ("org.gnome.gnome-2048");
        Window.set_default_icon_name ("org.gnome.TwentyFortyEight");

        try {
            GtkClutter.init_with_args (ref args, "", new OptionEntry[0], null);
        } catch (Error e) {
            MessageDialog dialog = new MessageDialog (null,
                                                      DialogFlags.MODAL,
                                                      MessageType.ERROR,
                                                      ButtonsType.NONE,
                                                      "Unable to initialize Clutter:\n%s", e.message);
            dialog.set_title (Environment.get_application_name ());
            dialog.run ();
            dialog.destroy ();
            return Posix.EXIT_FAILURE;
        }

        Application app = new Application ();
        return app.run (args);
    }

    public Application ()
    {
        Object (application_id: "org.gnome.gnome-2048", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        add_action_entries (action_entries, this);

        _settings = new GLib.Settings ("org.gnome.TwentyFortyEight");

/*        CssProvider provider = new CssProvider ();
        provider.load_from_resource ("/org/gnome/gnome-2048/data/style.css");
        StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, STYLE_PROVIDER_PRIORITY_APPLICATION); */

        _init_game ();

        _create_window ();

        _create_scores_dialog ();   // the library forbids to delay the dialog creation

        set_accels_for_action ("app.preferences",       {        "<Primary>e"       });
        set_accels_for_action ("app.toggle-new-game",   {        "<Primary>n"       });
        set_accels_for_action ("app.new-game",          { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q"       });
        set_accels_for_action ("app.undo",              {        "<Primary>z"       });
        set_accels_for_action ("app.about",             {          "<Shift>F1",
                                                          "<Shift><Primary>F1"      }); // as usual, this second shortcut does not work
        set_accels_for_action ("win.show-help-overlay", {                 "F1",
                                                                 "<Primary>F1",
                                                                 "<Primary>question",
                                                          "<Shift><Primary>question"});
        set_accels_for_action ("app.toggle-hamburger",  {                 "F10",
                                                                          "Menu"    });

        _window.notify ["has-toplevel-focus"].connect (() => embed.grab_focus ());
        _window.show_all ();

        _game_restored = _game.restore_game ();
        if (!_game_restored)
            new_game_cb ();
    }

    protected override void activate ()
    {
        _window.present ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        _game.save_game ();

        _settings.delay ();
        _settings.set_int ("window-width", _window_width);
        _settings.set_int ("window-height", _window_height);
        _settings.set_boolean ("window-maximized", _window_maximized);
        _settings.apply ();
    }

    private void _init_game ()
    {
        _game = new Game (_settings);
        _game.notify["score"].connect ((s, p) => {
                _score.label = _game.score.to_string ();
            });
        _game.finished.connect ((s) => {
                /* Translators: subtitle of the headerbar, when the user cannot move anymore */
                _header_bar.subtitle = _("Game Over");

                if (!_game_restored)
                    _show_best_scores ();

                debug ("finished");
            });
        _game.target_value_reached.connect (target_value_reached_cb);
        _game.undo_enabled.connect ((s) => {
                ((SimpleAction) lookup_action ("undo")).set_enabled (true);
            });
        _game.undo_disabled.connect ((s) => {
                ((SimpleAction) lookup_action ("undo")).set_enabled (false);
            });
    }

    private void _create_window ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/gnome-2048/data/mainwindow.ui");

        _window = (ApplicationWindow) builder.get_object ("applicationwindow");
        _window.set_default_size (_settings.get_int ("window-width"), _settings.get_int ("window-height"));
        if (_settings.get_boolean ("window-maximized"))
            _window.maximize ();

        add_window (_window);

        _create_header_bar (builder);
        _create_game_view (builder);

        _window.set_events (_window.get_events () | Gdk.EventMask.STRUCTURE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
        _window.key_press_event.connect (key_press_event_cb);
        _window.size_allocate.connect (window_size_allocate_cb);
        _window.window_state_event.connect (window_state_event_cb);

        Gdk.Geometry geom = Gdk.Geometry ();
        geom.min_height = WINDOW_MINIMUM_SIZE_HEIGHT;
        geom.min_width = WINDOW_MINIMUM_SIZE_WIDTH;
        _window.set_geometry_hints (_window, geom, Gdk.WindowHints.MIN_SIZE);
    }

    private void _create_header_bar (Builder builder)
    {
        _header_bar = (HeaderBar) builder.get_object ("headerbar");

        _score = (Label) builder.get_object ("score");

        ((SimpleAction) lookup_action ("undo")).set_enabled (false);

        _new_game_button = (MenuButton) builder.get_object ("new-game-button");
        _settings.changed.connect ((settings, key_name) => {
                if (key_name == "cols" || key_name == "rows")
                    _update_new_game_menu ();
            });
        _update_new_game_menu ();

        _hamburger_button = (MenuButton) builder.get_object ("hamburger-button");
        _hamburger_button.notify ["active"].connect (() => {
                if (!_hamburger_button.active)
                    embed.grab_focus ();
            });
        _settings.changed ["allow-undo"].connect (_update_hamburger_menu);
        _update_hamburger_menu ();
    }

    private void _create_game_view (Builder builder)
    {
        embed = new GtkClutter.Embed ();
        AspectFrame frame = (AspectFrame) builder.get_object ("aspectframe");
        frame.add (embed);
        _game.view = embed.get_stage ();
    }

    /*\
    * * hamburger menu (and undo action) callbacks
    \*/

    private void _update_hamburger_menu ()
    {
        GLib.Menu menu = new GLib.Menu ();

        if (_settings.get_boolean ("allow-undo"))
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
        section.append (_("Undo"), "app.undo");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void _append_scores_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: entry in the hamburger menu; opens a window showing best scores */
        section.append (_("Scores"), "app.scores");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void _append_app_actions_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: entry in the hamburger menu; opens a window for configuring application */
        section.append (_("Preferences"), "app.preferences");

        /* Translators: usual menu entry of the hamburger menu */
        section.append (_("Keyboard Shortcuts"), "win.show-help-overlay");

        /* Translators: entry in the hamburger menu */
        section.append (_("About 2048"), "app.about");

        section.freeze ();
        menu.append_section (null, section);
    }

    private void toggle_hamburger_menu (/* SimpleAction action, Variant? variant */)
    {
        _hamburger_button.active = !_hamburger_button.active;
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (_settings.get_boolean ("allow-undo"))   // for the keyboard shortcut
            _game.undo ();
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _header_bar.subtitle = null;
        _game_restored = false;

        _game.new_game ();

        embed.grab_focus ();
    }

    private void toggle_new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        _new_game_button.active = !_new_game_button.active;
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

        _game.reload_settings ();
        new_game_cb ();
    }

    private void about_cb (/* SimpleAction action, Variant? variant */)
    {
        string [] authors = { "Juan R. García Blanco", "Arnaud Bonatti" };
        show_about_dialog (_window,
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

    private void quit_cb (/* SimpleAction action, Variant? variant */)
    {
        _window.destroy ();
    }

    /*\
    * * new-game menu
    \*/

    private void _update_new_game_menu ()
    {
        GLib.Menu menu = new GLib.Menu ();

        /* Translators: on main window, entry of the menu when clicking on the "New Game" button; to change grid size to 4 × 4 */
        _append_new_game_item (_("4 × 4"), /* rows */ 4, /* cols */ 4, ref menu);

        /* Translators: on main window, entry of the menu when clicking on the "New Game" button; to change grid size to 5 × 5 */
        _append_new_game_item (_("5 × 5"), /* rows */ 5, /* cols */ 5, ref menu);

        int rows = _settings.get_int ("rows");
        int cols = _settings.get_int ("cols");
        bool disallowed_grid = is_disallowed_grid_size (ref rows, ref cols);
        if (disallowed_grid)
            warning (_("Grids of size 1 by 2 are disallowed."));

        if (((rows != cols) && !disallowed_grid)
         || ((rows == cols) && rows != 4 && rows != 5))
            /* Translators: on main window, entry of the menu when clicking on the "New Game" button; appears only if the user has set rows and cols manually */
            _append_new_game_item (_("Custom"), /* rows */ rows, /* cols */ cols, ref menu);

        menu.freeze ();
        _new_game_button.set_menu_model ((MenuModel) menu);
    }
    private static void _append_new_game_item (string label, int rows, int cols, ref GLib.Menu menu)
    {
        Variant variant = new Variant ("(ii)", rows, cols);
        menu.append (label, "app.new-game-sized(" + variant.print (/* annotate types */ true) + ")");
    }

    public static bool is_disallowed_grid_size (ref int rows, ref int cols)
    {
        return (rows == 1 && cols == 2) || (rows == 2 && cols == 1);
    }

    /*\
    * * window management callbacks
    \*/

    private bool key_press_event_cb (Widget widget, Gdk.EventKey event)
    {
        _game_restored = false;

        if (_hamburger_button.active || (_window.focus_visible && !embed.is_focus))
            return false;

        return _game.key_pressed (event);
    }

    private void window_size_allocate_cb ()
    {
        if (_window_maximized)
            return;
        _window.get_size (out _window_width, out _window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            _window_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        return false;
    }

    /*\
    * * preferences dialog
    \*/

    private Dialog      _preferences_dialog;
    private MenuButton  _animations_button;

    private bool _should_create_preferences_dialog = true;
    private inline void _create_preferences_dialog ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/gnome-2048/data/preferences.ui");

        _preferences_dialog = (Dialog) builder.get_object ("preferencesdialog");
        _preferences_dialog.set_application (this); // else we cannot use "app." actions in the dialog
        _preferences_dialog.set_transient_for (_window);

        _preferences_dialog.response.connect ((response_id) => {
                _preferences_dialog.hide_on_delete ();
            });
        _preferences_dialog.delete_event.connect ((response_id) => {
                _game.reload_settings ();
                return _preferences_dialog.hide_on_delete ();
            });

        _settings.bind ("do-congrat",       builder.get_object ("congratswitch"),   "active", GLib.SettingsBindFlags.DEFAULT);
        _settings.bind ("allow-undo",       builder.get_object ("undoswitch"),      "active", GLib.SettingsBindFlags.DEFAULT);

        _animations_button = (MenuButton) builder.get_object ("animations-button");
        _settings.changed ["animations-speed"].connect (_set_animations_button_label);
        _set_animations_button_label (_settings, "animations-speed");
    }
    private inline void _set_animations_button_label (GLib.Settings settings, string key_name)
    {
        double speed = settings.get_double (key_name);
        string _animations_button_label;
        _get_animations_button_label (ref speed, out _animations_button_label);
        _animations_button.set_label (_animations_button_label);
    }
    private static inline void _get_animations_button_label (ref double speed, out string _animations_button_label)
    {
        if (speed == 100.0)
            /* Translators: in the preferences dialog; possible label of the MenuButton to choose animation speed */
            _animations_button_label = _("Normal");

        else if (speed == 40.0)
            /* Translators: in the preferences dialog; possible label of the MenuButton to choose animation speed */
            _animations_button_label = _("Fast");

        else if (speed == 250.0)
            /* Translators: in the preferences dialog; possible label of the MenuButton to choose animation speed */
            _animations_button_label = _("Slow");

        else
            /* Translators: in the preferences dialog; possible label of the MenuButton to choose animation speed */
            _animations_button_label = _("Custom");
    }

    private inline void _animations_speed (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        double speed = double.parse (((!) variant).get_string ());
        _settings.set_double ("animations-speed", speed);
    }

    private inline void preferences_cb (/* SimpleAction action, Variant? variant */)
    {
        if (_should_create_preferences_dialog)
        {
            _create_preferences_dialog ();
            _should_create_preferences_dialog = false;
        }

        _preferences_dialog.present ();
    }

    /*\
    * * congratulations dialog
    \*/

    private MessageDialog _congrats_dialog;

    private bool _should_create_congrats_dialog = true;
    private inline void _create_congrats_dialog ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/gnome-2048/data/congrats.ui");

        _congrats_dialog = (MessageDialog) builder.get_object ("congratsdialog");
        _congrats_dialog.set_transient_for (_window);

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
    private Scores.Category _grid5_cat;

    private inline void _create_scores_dialog ()
    {
        /* Translators: combobox entry in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 4 × 4 and one 5 × 5 game */
        _grid4_cat = new Scores.Category ("grid4", _("Grid 4 × 4"));

        /* Translators: combobox entry in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 4 × 4 and one 5 × 5 game */
        _grid5_cat = new Scores.Category ("grid5", _("Grid 5 × 5"));

        /* Translators: label introducing a combobox in the dialog that appears when the user clicks the "Scores" entry in the hamburger menu, if the user has already finished at least one 4 × 4 and one 5 × 5 game */
        _scores_ctx = new Scores.Context ("gnome-2048", _("Grid Size:"), _window, category_request, Scores.Style.POINTS_GREATER_IS_BETTER);
    }
    private inline Games.Scores.Category category_request (string key)
    {
        switch (key)
        {
            case "grid4": return _grid4_cat;
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
        if (rows != 4 && rows != 5)
            return;                 // FIXME add categories for non-usual square grids

        Scores.Category cat = (rows == 4) ? _grid4_cat : _grid5_cat;
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
}
