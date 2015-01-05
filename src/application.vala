/* gnome-2048 Copyright (C) 2014-2015 Juan R. García Blanco
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

public class Application : Gtk.Application
{
  private GLib.Settings _settings;

  private Gtk.Window _window;
  private Gtk.HeaderBar _header_bar;
  private Gtk.Button _new_game_button;
  private Gtk.AboutDialog _about_dialog;
  private Gtk.Dialog _preferences_dialog;
  private Gtk.Dialog _scores_dialog;
  private Gtk.Label _score;

  private int _window_width;
  private int _window_height;
  private bool _window_maximized;

  private Game _game;

  private const GLib.ActionEntry[] action_entries =
  {
    { "new-game",       new_game_cb       },
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
    _create_scores_dialog (builder);

    _game.new_game ();
  }

  protected override void shutdown ()
  {
    base.shutdown ();

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
      _scores_dialog.present ();
      debug ("finished");
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

    _window.show_all ();
  }

  private void _create_header_bar ()
  {
    _header_bar = new Gtk.HeaderBar ();
    _header_bar.show_close_button = true;
    _header_bar.title = "Gnome 2048";
    _window.set_titlebar (_header_bar);

    _score = new Gtk.Label ("0");
    _header_bar.pack_end (_score);

    _new_game_button = new Gtk.Button.with_label (_("New Game"));
    _new_game_button.set_action_name ("app.new-game");
    _header_bar.pack_start (_new_game_button);
  }

  private void _create_game_view (Gtk.Builder builder)
  {
    var embed = new GtkClutter.Embed ();
    var grid = builder.get_object ("grid") as Gtk.Grid;
    grid.attach (embed, 0, 0, 1, 1);
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
    _about_dialog.copyright = "Copyright © 2014 Juan R. García Blanco";
    _about_dialog.version = "0.1";
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

    _preferences_dialog.response.connect ((response_id) => {
      _preferences_dialog.hide_on_delete ();
    });
    _preferences_dialog.delete_event.connect ((response_id) => {
      _game.reload_settings ();
      _game.new_game ();
      return _preferences_dialog.hide_on_delete ();
    });

    _settings.bind ("rows", builder.get_object ("rowsspin"), "value", GLib.SettingsBindFlags.DEFAULT);
    _settings.bind ("cols", builder.get_object ("colsspin"), "value", GLib.SettingsBindFlags.DEFAULT);
  }

  private void _create_scores_dialog (Gtk.Builder builder)
  {
    try {
      builder.add_from_resource ("/org/gnome/gnome-2048/data/scoreboard.ui");
    } catch (GLib.Error e) {
      stderr.printf ("%s\n", e.message);
    }

    _scores_dialog = builder.get_object ("scoresdialog") as Gtk.Dialog;
    _scores_dialog.set_transient_for (_window);

    _scores_dialog.response.connect ((response_id) => {
      _scores_dialog.hide_on_delete ();
    });
    _scores_dialog.delete_event.connect ((response_id) => {
      return _scores_dialog.hide_on_delete ();
    });
  }

  private void new_game_cb ()
  {
    _header_bar.subtitle = null;

    _game.new_game ();
  }

  private void about_cb ()
  {
    _about_dialog.present ();
  }

  private void preferences_cb ()
  {
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

    Environment.set_application_name (_("2048"));
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
