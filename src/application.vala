/* Copyright (C) 2014-2015 Juan R. García Blanco
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

public class Application : Gtk.Application
{
  private GLib.Settings _settings;

  private Gtk.Window _window;
  private Gtk.HeaderBar _header_bar;
  private Gtk.Button _undo_button;
  private Gtk.Button _new_game_button;
  private Gtk.AboutDialog _about_dialog;
  private Gtk.Dialog _preferences_dialog;
  private Gtk.Dialog _congrats_dialog;
  private Gtk.Label _congrats_message;
  private Gtk.Label _score;
  private Gtk.ComboBoxText _grid_size_combo;

  private Scores.Context _scores_ctx;
  private Scores.Category _grid4_cat;
  private Scores.Category _grid5_cat;

  private bool _game_restored;

  private int _window_width;
  private int _window_height;
  private bool _window_maximized;

  private int WINDOW_MINIMUM_SIZE_HEIGHT = 600;
  private int WINDOW_MINIMUM_SIZE_WIDTH = 600;

  private Game _game;

  private const GLib.ActionEntry[] action_entries =
  {
    { "new-game",       new_game_cb       },
    { "undo",           undo_cb           },
    { "scores",         scores_cb         },
    { "about",          about_cb          },
    { "preferences",    preferences_cb    },
    { "quit",           quit_cb           },
    { "help",           help_cb           }
  };

  public Application ()
  {
    Object (application_id: "org.gnome.gnome-2048", flags: ApplicationFlags.FLAGS_NONE);
  }

  protected override void startup ()
  {
    base.startup ();

    add_action_entries (action_entries, this);
    add_accelerator ("F1", "app.help", null);

    _settings = new Settings ("org.gnome.2048");

    _init_style ();
    _init_app_menu ();
    _init_game ();
  }

  protected override void activate ()
  {
    base.activate ();

    var builder = new Gtk.Builder ();
    _create_window (builder);
    _create_about_dialog ();
    _create_preferences_dialog (builder);
    _create_congrats_dialog (builder);

    _create_scores ();

    _window.show_all ();

    _game_restored = _game.restore_game ();
    if (!_game_restored)
      new_game_cb ();
  }

  protected override void shutdown ()
  {
    base.shutdown ();

    _game.save_game ();

    _settings.set_int ("window-width", _window_width);
    _settings.set_int ("window-height", _window_height);
    _settings.set_boolean ("window-maximized", _window_maximized);
  }

  private void _init_style ()
  {
    var provider = new Gtk.CssProvider ();
    try
    {
      provider.load_from_file (GLib.File.new_for_uri ("resource://org/gnome/gnome-2048/data/style.css"));
      Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void _init_app_menu ()
  {
    var builder = new Gtk.Builder ();
    try {
      builder.add_from_resource ("/org/gnome/gnome-2048/data/menus.ui");
      var menu = builder.get_object ("app-menu") as GLib.MenuModel;
      set_app_menu (menu);
    } catch (GLib.Error e) {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void _init_game ()
  {
    _game = new Game (_settings);
    _game.notify["score"].connect ((s, p) => {
      _score.label = _game.score.to_string ();
    });
    _game.finished.connect ((s) => {
      _header_bar.subtitle = _("Game Over");

      if (!_game_restored) {
        Scores.Category cat = (_settings.get_int ("rows") == 4) ? _grid4_cat : _grid5_cat;
        _scores_ctx.add_score.begin (_game.score, cat, null, (object, result) => {
          try {
            _scores_ctx.add_score.end (result);
          } catch (GLib.Error e) {
            stderr.printf ("%s\n", e.message);
          }
          ((SimpleAction) lookup_action ("scores")).set_enabled (true);
          debug ("score added");
        });
      }

      debug ("finished");
    });
    _game.target_value_reached.connect ((s, v) => {
      if (_settings.get_boolean ("do-congrat")) {
        string message = _("You have obtained the %u tile".printf (v));
        _congrats_message.set_text (message);
        _congrats_dialog.present ();
        _settings.set_boolean ("do-congrat", false);
      }
      debug ("target value reached");
    });
    _game.undo_enabled.connect ((s) => {
      ((SimpleAction) lookup_action ("undo")).set_enabled (true);
    });
    _game.undo_disabled.connect ((s) => {
      ((SimpleAction) lookup_action ("undo")).set_enabled (false);
    });
  }

  private void _create_window (Gtk.Builder builder)
  {
    try {
      builder.add_from_resource ("/org/gnome/gnome-2048/data/mainwindow.ui");
    } catch (GLib.Error e) {
      stderr.printf ("%s\n", e.message);
    }

    _window = builder.get_object ("applicationwindow") as Gtk.ApplicationWindow;
    _window.set_default_size (_settings.get_int ("window-width"), _settings.get_int ("window-height"));
    if (_settings.get_boolean ("window-maximized"))
      _window.maximize ();

    add_window (_window);

    _create_header_bar ();
    _create_game_view (builder);

    _window.set_events (_window.get_events () | Gdk.EventMask.STRUCTURE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
    _window.key_press_event.connect (key_press_event_cb);
    _window.configure_event.connect (window_configure_event_cb);
    _window.window_state_event.connect (window_state_event_cb);

    Gdk.Geometry geom = Gdk.Geometry ();
    geom.min_height = WINDOW_MINIMUM_SIZE_HEIGHT;
    geom.min_width = WINDOW_MINIMUM_SIZE_WIDTH;
    _window.set_geometry_hints (_window, geom, Gdk.WindowHints.MIN_SIZE);
  }

  private void _create_header_bar ()
  {
    _header_bar = new Gtk.HeaderBar ();
    _header_bar.show_close_button = true;
    _header_bar.title = "2048";
    _window.set_titlebar (_header_bar);

    _score = new Gtk.Label ("0");
    _header_bar.pack_end (_score);

    _undo_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic");
    _undo_button.set_action_name ("app.undo");
    _header_bar.pack_start (_undo_button);
    ((SimpleAction) lookup_action ("undo")).set_enabled (false);

    _new_game_button = new Gtk.Button.with_label (_("New Game"));
    _new_game_button.set_action_name ("app.new-game");
    _header_bar.pack_start (_new_game_button);
  }

  private void _create_game_view (Gtk.Builder builder)
  {
    var embed = new GtkClutter.Embed ();
    var frame = builder.get_object ("aspectframe") as Gtk.AspectFrame;
    frame.add (embed);
    _game.view = embed.get_stage ();
  }

  private void _create_about_dialog ()
  {
    _about_dialog = new Gtk.AboutDialog ();
    _about_dialog.set_transient_for (_window);
    _about_dialog.destroy_with_parent = true;
    _about_dialog.modal = true;

    _about_dialog.program_name = "2048";
    _about_dialog.logo_icon_name = "gnome-2048";
    _about_dialog.comments = _("A clone of 2048 for GNOME");

    _about_dialog.authors = {"Juan R. García Blanco"};
    _about_dialog.copyright = "Copyright © 2014-2015 Juan R. García Blanco";
    _about_dialog.version = VERSION;
    _about_dialog.website = "http://www.gnome.org";
    _about_dialog.license_type = Gtk.License.GPL_3_0;
    _about_dialog.wrap_license = false;

    _about_dialog.response.connect ((response_id) => {
      _about_dialog.hide ();
    });
    _about_dialog.delete_event.connect ((response_id) => {
      return _about_dialog.hide_on_delete ();
    });
  }

  private void _create_preferences_dialog (Gtk.Builder builder)
  {
    try {
      builder.add_from_resource ("/org/gnome/gnome-2048/data/preferences.ui");
    } catch (GLib.Error e) {
      stderr.printf ("%s\n", e.message);
    }

    _preferences_dialog = builder.get_object ("preferencesdialog") as Gtk.Dialog;
    _preferences_dialog.set_transient_for (_window);

    _grid_size_combo = builder.get_object ("gridsizecombo") as Gtk.ComboBoxText;

    _preferences_dialog.response.connect ((response_id) => {
      _preferences_dialog.hide_on_delete ();
    });
    _preferences_dialog.delete_event.connect ((response_id) => {
      int grid_size;
      int rows, cols;
      bool settings_changed;

      grid_size = _grid_size_combo.get_active ();
      if (grid_size == 0) {
        rows = cols = 4;
      } else {
        rows = cols = 5;
      }

      _settings.set_int ("rows", rows);
      _settings.set_int ("cols", cols);

      settings_changed = _game.reload_settings ();
      if (settings_changed)
        new_game_cb ();
      return _preferences_dialog.hide_on_delete ();
    });

    _settings.bind ("do-congrat", builder.get_object ("congratswitch"), "active", GLib.SettingsBindFlags.DEFAULT);
    _settings.bind ("animations-speed", builder.get_object ("animationsspeed"), "value", GLib.SettingsBindFlags.DEFAULT);
    _settings.bind ("allow-undo", builder.get_object ("undoswitch"), "active", GLib.SettingsBindFlags.DEFAULT);
  }

  private void _create_congrats_dialog (Gtk.Builder builder)
  {
    try {
      builder.add_from_resource ("/org/gnome/gnome-2048/data/congrats.ui");
    } catch (GLib.Error e) {
      stderr.printf ("%s\n", e.message);
    }

    _congrats_dialog = builder.get_object ("congratsdialog") as Gtk.Dialog;
    _congrats_dialog.set_transient_for (_window);

    _congrats_dialog.response.connect ((response_id) => {
      if (response_id == 0)
        new_game_cb ();
      _congrats_dialog.hide ();
    });
    _congrats_dialog.delete_event.connect ((response_id) => {
      return _congrats_dialog.hide_on_delete ();
    });

    _congrats_message = builder.get_object ("messagelabel") as Gtk.Label;
  }

  private Games.Scores.Category category_request (string key)
  {
    if (key == "grid4")
      return _grid4_cat;
    else if (key == "grid5")
      return _grid5_cat;
    assert_not_reached ();
  }

  private void _create_scores ()
  {
    // FIXME: The category names should be marked for translation and use the × character.
    _grid4_cat = new Scores.Category ("grid4", "Grid 4 x 4");
    _grid5_cat = new Scores.Category ("grid5", "Grid 5 x 5");

    // FIXME: The second parameter should be _("Grid Size:") but we're in string freeze.
    _scores_ctx = new Scores.Context ("gnome-2048", "", _window, category_request, Scores.Style.PLAIN_DESCENDING);
  }

  private void new_game_cb ()
  {
    _header_bar.subtitle = null;
    _game_restored = false;

    _game.new_game ();
  }

  private void undo_cb ()
  {
    _game.undo ();
  }

  private void scores_cb ()
  {
    _scores_ctx.run_dialog ();
  }

  private void about_cb ()
  {
    _about_dialog.present ();
  }

  private void preferences_cb ()
  {
    int grid_size;
    int rows;

    rows = _settings.get_int ("rows");

    if (rows == 4) {
      grid_size = 0;
    } else {
      grid_size = 1;
    }

    _grid_size_combo.set_active (grid_size);

    _preferences_dialog.present ();
  }

  private void quit_cb ()
  {
    _window.destroy ();
  }

  private void help_cb ()
  {
    try {
      Gtk.show_uri (_window.get_screen (), "help:gnome-2048", Gtk.get_current_event_time ());
    } catch (GLib.Error e) {
      warning ("Failed to show help: %s", e.message);
    }
  }

  private bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event)
  {
    _game_restored = false;

    return _game.key_pressed (event);
  }

  private bool window_configure_event_cb (Gdk.EventConfigure event)
  {
    if (!_window_maximized) {
      _window_width = event.width;
      _window_height = event.height;
    }

    return false;
  }

  private bool window_state_event_cb (Gdk.EventWindowState event)
  {
    if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
      _window_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

    return false;
  }

  public static int main (string[] args)
  {
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (GETTEXT_PACKAGE);

    var context = new OptionContext ("");

    context.add_group (Gtk.get_option_group (true));
    context.add_group (Clutter.get_option_group_without_init ());

    try {
      context.parse (ref args);
    } catch (Error e) {
      stderr.printf ("%s\n", e.message);
      return Posix.EXIT_FAILURE;
    }

    Environment.set_application_name ("org.gnome.gnome-2048");
    Gtk.Window.set_default_icon_name ("gnome-2048");

    try {
      GtkClutter.init_with_args (ref args, "", new OptionEntry[0], null);
    } catch (Error e) {
      var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.NONE, "Unable to initialize Clutter:\n%s", e.message);
      dialog.set_title (Environment.get_application_name ());
      dialog.run ();
      dialog.destroy ();
      return Posix.EXIT_FAILURE;
    }

    var app = new Application ();
    return app.run (args);
  }
}
