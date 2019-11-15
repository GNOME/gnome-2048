/*
   This file is part of GNOME 2048.

   Copyright (C) 2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>

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

namespace CLI
{
    private static int play_cli (string cli, string schema_name, ref uint8 cols, ref uint8 rows)
    {
        if ((cols != 0 || rows != 0) && cli != "new")
        {
            warning ("Size can only be given for new games." + "\n");
            return Posix.EXIT_FAILURE;
        }

        string saved_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-2048", "saved");

        GLib.Settings settings = new GLib.Settings (schema_name);

        bool new_game;
        Grid grid;
        if (cols != 0 || rows != 0)
        {
            if (cols == 0 || rows == 0)
                assert_not_reached ();

            settings.delay ();
            settings.set_int ("cols", cols);
            settings.set_int ("rows", rows);
            settings.apply ();
            GLib.Settings.sync ();

            grid = new Grid (rows, cols);
            new_game = true;
        }
        else
        {
            cols = (uint8) settings.get_int ("cols");  // schema ranges rows
            rows = (uint8) settings.get_int ("rows"); // and cols from 1 to 9

            grid = new Grid (rows, cols);
            if (cli == "new")
                new_game = true;
            else if (!grid.restore_game (saved_path))
                new_game = true;
            else
            {
                new_game = false;
                cols = grid.cols;
                rows = grid.rows;
            }
        }
        grid.target_value = (uint) settings.get_int ("target-value");

        if (new_game)
        {
            Tile tile;
            grid.new_tile (out tile);   // TODO clean that
        }

        switch (cli)
        {
            case "help":
            case "HELP":
                assert_not_reached ();  // should be handled by the caller

            case "":
            case "show":
            case "status":
                if (new_game)
                    break;

                print_board (cols, rows, grid, /* do congrat */ false, /* print score */ true);
                return Posix.EXIT_SUCCESS;

            case "new": // creation already handled, need saving
                break;

            case "r":
            case "right":
                if (!request_move (grid, MoveRequest.RIGHT))
                    return Posix.EXIT_FAILURE;
                break;

            case "l":
            case "left":
                if (!request_move (grid, MoveRequest.LEFT))
                    return Posix.EXIT_FAILURE;
                break;

            case "u":
            case "up":
                if (!request_move (grid, MoveRequest.UP))
                    return Posix.EXIT_FAILURE;
                break;

            case "d":
            case "down":
                if (!request_move (grid, MoveRequest.DOWN))
                    return Posix.EXIT_FAILURE;
                break;

            default:
                warning ("Cannot parse “--cli” command, aborting." + "\n");
                return Posix.EXIT_FAILURE;
        }

        Tile? new_tile = null;
        if (!grid.is_finished ())
        {
            grid.new_tile (out new_tile);
            if (cli == "new")
                new_tile = null;
        }

        bool do_congrat = settings.get_boolean ("do-congrat");
        if (do_congrat && grid.target_value_reached)
            settings.set_boolean ("do-congrat", false);

        print_board (cols, rows, grid, do_congrat, /* print score */ false, new_tile);

        if (!grid.is_finished ()    // one more tile since previously
         || grid.cols != grid.rows
         || grid.cols < 3 || grid.cols > 5)
            grid.save_game (saved_path);

        return Posix.EXIT_SUCCESS;
    }

    /*\
    * * move request
    \*/

    private static bool request_move (Grid grid, MoveRequest req)
    {
        if (!can_play (grid))
            return false;

        Gee.LinkedList<TileMovement?> to_move = new Gee.LinkedList<TileMovement?> ();
        Gee.LinkedList<TileMovement?> to_hide = new Gee.LinkedList<TileMovement?> ();
        Gee.LinkedList<Tile?>         to_show = new Gee.LinkedList<Tile?> ();

        grid.move (req, ref to_move, ref to_hide, ref to_show); // TODO do not request so many unused things
        if (!has_moves (ref to_move, ref to_hide))
            return false;

        return true;
    }

    private static inline bool can_play (Grid grid)
    {
        if (!grid.is_finished ())
            return true;

        warning ("Grid is finished, impossible to move." + "\n");
        return false;
    }

    private static inline bool has_moves (ref Gee.LinkedList<TileMovement?> to_move,
                                          ref Gee.LinkedList<TileMovement?> to_hide)
    {
        if (to_move.size != 0 || to_hide.size != 0)
            return true;

        warning ("Impossible to move in that direction." + "\n");
        return false;
    }

    /*\
    * * print board
    \*/

    private static void print_board (uint8 cols, uint8 rows, Grid grid, bool do_congrat, bool print_score, Tile? new_tile = null)
    {
        string board = "";

        board += "\n ┏";
        for (uint8 i = 0; i <= 7 * cols; i++)
            board += "━";
        board += "┓\n";

        for (uint8 y = 0; y < rows; y++)
        {
            board += " ┃";
            for (uint8 x = 0; x < cols; x++)
            {
                if (grid [y, x] == 0)               // FIXME inverted coordinates
                    board += "       ";
                else
                    board += " ╭────╮";
            }
            board += " ┃\n ┃";
            for (uint8 x = 0; x < cols; x++)
            {
                uint8 tile_value = grid [y, x];
                if (tile_value == 0)
                    board += "       ";
                else
                {
                    string tile_value_string = tile_value.to_string ();
                    if (tile_value == 1 && new_tile != null && ((!) new_tile).pos.col == x && ((!) new_tile).pos.row == y)
                        board +=  " │ +1 │";
                    else if (tile_value_string.length == 1)
                        board += @" │  $tile_value_string │";
                    else if (tile_value_string.length == 2)
                        board += @" │ $tile_value_string │";
                    else assert_not_reached ();
                }
            }
            board += " ┃\n ┃";
            for (uint8 x = 0; x < cols; x++)
            {
                if (grid [y, x] == 0)
                    board += "       ";
                else
                    board += " ╰────╯";
            }
            board += " ┃\n";
        }

        board += " ┗";
        for (uint8 i = 0; i <= 7 * cols; i++)
            board += "━";
        board += "┛\n\n";

        if (do_congrat && grid.target_value_reached) // try to keep string as in game-window.vala
            board += " " + "You have obtained the %u tile for the first time!".printf (grid.target_value_simple) + "\n\n";

        if (grid.is_finished ())
        {
            if (print_score     // called from “--cli show”
             || grid.cols != grid.rows
             || grid.cols < 3 || grid.cols > 5)
                board += @" Game is finished! Your score is $(grid.get_score ()).\n\n";
            else                // game was just finished and score can be saved
                board += @" Game is finished! Your score is $(grid.get_score ()). (If you want to save it, use GNOME 2048 graphical interface.)\n\n"; // TODO save score
        }
        else if (print_score)
            board += @" Your score is $(grid.get_score ()).\n\n";

        stdout.printf (board);
    }

    /*\
    * * parse command-line input size
    \*/

    private static inline bool parse_size (string size, out uint8 cols, out uint8 rows)
    {
        cols = 0;   // garbage
        rows = 0;   // garbage

        /* size is either a digit, either of the for MxN */
        string [] tokens = size.split ("x");
        if (tokens.length == 0 || tokens.length > 2)
            return false;

        /* parse the first token in any case */
        uint64 test;
        if (!uint64.try_parse (tokens [0], out test))
            return false;
        if (test <= 0 || test > 9)
            return false;
        cols = (uint8) test;

        /* test for forbidden "1" size and return */
        if (tokens.length == 1)
        {
            if (cols < 2)
                return false;
            rows = cols;
            return true;
        }

        /* parse the second token, if any */
        if (!uint64.try_parse (tokens [1], out test))
            return false;
        if (test <= 0 || test > 9)
            return false;
        rows = (uint8) test;

        /* test for forbidden sizes, and return */
        if (Grid.is_disallowed_grid_size (ref cols, ref rows))
            return false;

        return true;
    }
}
