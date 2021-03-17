/*
   This file is part of GNOME 2048.

   Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
   Copyright (C) 2016-2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>

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

using Gtk;

[GtkTemplate (ui = "/org/gnome/TwentyFortyEight/ui/game-headerbar.ui")]
private class GameHeaderBar : HeaderBar
{
    [GtkChild] private unowned Label        _score;
    [GtkChild] private unowned MenuButton   _new_game_button;
    [GtkChild] private unowned MenuButton   _hamburger_button;

    /*\
    * * popovers
    \*/

    internal signal void popover_closed ();

    construct
    {
        _hamburger_button.notify ["active"].connect (test_popover_closed);
        _new_game_button.notify ["active"].connect (test_popover_closed);
    }

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
        set_subtitle (null);
        set_has_subtitle (false);
    }

    internal void finished ()
    {
        set_has_subtitle (true);
        /* Translators: subtitle of the headerbar, when the user cannot move anymore */
        subtitle = _("Game Over");
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

    internal void toggle_hamburger_menu ()
    {
        _hamburger_button.active = !_hamburger_button.active;
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

    internal void toggle_new_game ()
    {
        _new_game_button.active = !_new_game_button.active;
    }
}
