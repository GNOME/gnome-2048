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

private class Grid : Object
{
    private uint8 [,] _grid;

    public int rows { internal get; protected construct; }
    public int cols { internal get; protected construct; }

    internal uint target_value          { internal get; internal set; default = 0; }
    internal bool target_value_reached  { internal get; internal set; default = false; }

    construct
    {
        _grid = new uint8 [rows, cols];
        _clear (ref _grid);
    }

    internal Grid (int rows, int cols)
    {
        Object (rows: rows, cols: cols);
    }

    /*\
    * * adding new tile
    \*/

    internal void new_tile (out Tile tile)
    {
        if (_grid_is_full (ref _grid))
            assert_not_reached ();

        GridPosition pos = { 0, 0 }; // TODO report bug: garbage init needed
        do { _generate_random_position (rows, cols, out pos); }
        while (_grid [pos.row, pos.col] != 0);

        _grid [pos.row, pos.col] = 1;
        tile = { pos, /* tile value */ 1 };
    }

    private static inline void _generate_random_position (int rows, int cols, out GridPosition pos)
        requires (rows > 0)
        requires (cols > 0)
    {
        pos = { Random.int_range (0, rows),
                Random.int_range (0, cols) };
    }

    /*\
    * * moving
    \*/

    internal inline void move (MoveRequest request,
                           ref Gee.LinkedList<TileMovement?> to_move,
                           ref Gee.LinkedList<TileMovement?> to_hide,
                           ref Gee.LinkedList<Tile?> to_show)
    {
        to_move.clear ();
        to_hide.clear ();
        to_show.clear ();

        uint8 max_changed = 0;
        switch (request)
        {
            case MoveRequest.DOWN:
                _move_down  (_cols, _rows, ref max_changed, ref _grid, ref to_move, ref to_hide, ref to_show); break;
            case MoveRequest.UP:
                _move_up    (_cols, _rows, ref max_changed, ref _grid, ref to_move, ref to_hide, ref to_show); break;
            case MoveRequest.LEFT:
                _move_left  (_cols, _rows, ref max_changed, ref _grid, ref to_move, ref to_hide, ref to_show); break;
            case MoveRequest.RIGHT:
                _move_right (_cols, _rows, ref max_changed, ref _grid, ref to_move, ref to_hide, ref to_show); break;
        }
        if (Math.pow (2, max_changed) >= target_value)
            target_value_reached = true;
    }

    private static void _move_down (int cols,
                                    int rows,
                                ref uint8 max_changed,
                                ref uint8 [,] grid,
                                ref Gee.LinkedList<TileMovement?> to_move,
                                ref Gee.LinkedList<TileMovement?> to_hide,
                                ref Gee.LinkedList<Tile?> to_show)
    {
        for (int i = 0; i < cols; i++)
        {
            GridPosition free = { rows, i };

            for (int j = 0; j < rows; j++)
            {
                int row = rows - j - 1;
                GridPosition cur = { row, i };
                uint8 val = grid [cur.row, cur.col];

                if (val == 0)
                {
                    if (free.row == rows)
                        free.row = row;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = row - 1; k >= 0; k--)
                {
                    uint8 k_val = grid [k, cur.col];

                    if (k_val != 0)
                    {
                        if (k_val == val)
                        {
                            has_match = true;
                            match = { k, cur.col };
                        }
                        break;
                    }
                }

                if (has_match)
                {
                    if (free.row == rows)
                        free.row = row; // temporarily

                    _move_to_match (ref to_hide, ref to_show, ref cur, ref free, ref match, ref grid, ref val, ref max_changed);
                    free.row--;
                }
                else if (free.row != rows)
                {
                    _move_to_end (ref to_move, ref cur, ref free, ref grid, ref val);
                    free.row--;
                }
            }
        }
    }

    private static void _move_up (int cols,
                                  int rows,
                              ref uint8 max_changed,
                              ref uint8 [,] grid,
                              ref Gee.LinkedList<TileMovement?> to_move,
                              ref Gee.LinkedList<TileMovement?> to_hide,
                              ref Gee.LinkedList<Tile?> to_show)
    {
        for (int i = 0; i < cols; i++)
        {
            GridPosition free = { -1, i };

            for (int j = 0; j < rows; j++)
            {
                int row = j;
                GridPosition cur = { row, i };
                uint8 val = grid [cur.row, cur.col];

                if (val == 0)
                {
                    if (free.row == -1)
                        free.row = row;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = row + 1; k < rows; k++)
                {
                    uint8 k_val = grid [k, cur.col];

                    if (k_val != 0)
                    {
                        if (k_val == val)
                        {
                            has_match = true;
                            match = { k, cur.col };
                        }
                        break;
                    }
                }

                if (has_match)
                {
                    if (free.row == -1)
                        free.row = row; // temporarily

                    _move_to_match (ref to_hide, ref to_show, ref cur, ref free, ref match, ref grid, ref val, ref max_changed);
                    free.row++;
                }
                else if (free.row != -1)
                {
                    _move_to_end (ref to_move, ref cur, ref free, ref grid, ref val);
                    free.row++;
                }
            }
        }
    }

    private static void _move_left (int cols,
                                    int rows,
                                ref uint8 max_changed,
                                ref uint8 [,] grid,
                                ref Gee.LinkedList<TileMovement?> to_move,
                                ref Gee.LinkedList<TileMovement?> to_hide,
                                ref Gee.LinkedList<Tile?> to_show)
    {
        for (int i = 0; i < rows; i++)
        {
            GridPosition free = { i, -1 };

            for (int j = 0; j < cols; j++)
            {
                int col = j;
                GridPosition cur = { i, col };
                uint8 val = grid [cur.row, cur.col];

                if (val == 0)
                {
                    if (free.col == -1)
                        free.col = col;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = col + 1; k < cols; k++)
                {
                    uint8 k_val = grid [cur.row, k];

                    if (k_val != 0)
                    {
                        if (k_val == val)
                        {
                            has_match = true;
                            match = { cur.row, k };
                        }
                        break;
                    }
                }

                if (has_match)
                {
                    if (free.col == -1)
                        free.col = col; // temporarily

                    _move_to_match (ref to_hide, ref to_show, ref cur, ref free, ref match, ref grid, ref val, ref max_changed);
                    free.col++;
                }
                else if (free.col != -1)
                {
                    _move_to_end (ref to_move, ref cur, ref free, ref grid, ref val);
                    free.col++;
                }
            }
        }
    }

    private static void _move_right (int cols,
                                     int rows,
                                 ref uint8 max_changed,
                                 ref uint8 [,] grid,
                                 ref Gee.LinkedList<TileMovement?> to_move,
                                 ref Gee.LinkedList<TileMovement?> to_hide,
                                 ref Gee.LinkedList<Tile?> to_show)
    {
        for (int i = 0; i < rows; i++)
        {
            GridPosition free = { i, cols };

            for (int j = 0; j < cols; j++)
            {
                int col = cols - j - 1;
                GridPosition cur = { i, col };
                uint8 val = grid [cur.row, cur.col];

                if (val == 0)
                {
                    if (free.col == cols)
                        free.col = col;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = col - 1; k >= 0; k--)
                {
                    uint8 k_val = grid [cur.row, k];

                    if (k_val != 0)
                    {
                        if (k_val == val)
                        {
                            has_match = true;
                            match = { cur.row, k };
                        }
                        break;
                    }
                }

                if (has_match)
                {
                    if (free.col == cols)
                        free.col = col; // temporarily

                    _move_to_match (ref to_hide, ref to_show, ref cur, ref free, ref match, ref grid, ref val, ref max_changed);
                    free.col--;
                }
                else if (free.col != cols)
                {
                    _move_to_end (ref to_move, ref cur, ref free, ref grid, ref val);
                    free.col--;
                }
            }
        }
    }

    /*\
    * * move utilities
    \*/

    private static void _move_to_match (ref Gee.LinkedList<TileMovement?> to_hide,
                                        ref Gee.LinkedList<Tile?> to_show,
                                        ref GridPosition cur,
                                        ref GridPosition free,
                                        ref GridPosition match,
                                        ref uint8 [,] grid,
                                        ref uint8 val,
                                        ref uint8 max_changed)
    {
        debug (@"matching tile found at $match");

        TileMovement mov = { cur, free };
        to_hide.add (mov);
        mov = { match, free };
        to_hide.add (mov);

        val++;
        Tile tile = { free, val };
        to_show.add (tile);

        grid [cur.row, cur.col] = 0;
        grid [match.row, match.col] = 0;
        grid [free.row, free.col] = val;
        if (max_changed < val)
            max_changed = val;
    }

    private static void _move_to_end (ref Gee.LinkedList<TileMovement?> to_move,
                                      ref GridPosition cur,
                                      ref GridPosition free,
                                      ref uint8 [,] grid,
                                      ref uint8 val)
    {
        debug (@"moving $cur to $free");

        TileMovement mov = { cur, free };
        to_move.add (mov);

        grid [cur.row, cur.col] = 0;
        grid [free.row, free.col] = val;
    }

    /*\
    * * work on all the grid
    \*/

    internal bool is_finished ()
    {
        if (!_grid_is_full (ref _grid))
            return false;

        for (int i = 0; i < _rows; i++)
        {
            for (int j = 0; j < _cols; j++)
            {
                uint8 val = _grid [i, j];

                if (i < (_rows - 1) && val == _grid [i+1, j])
                    return false;

                if (j < (_cols - 1) && val == _grid [i, j+1])
                    return false;
            }
        }

        return true;
    }

    private static bool _grid_is_full (ref uint8 [,] grid)
    {
        uint rows = grid.length [0];
        uint cols = grid.length [1];

        for (uint i = 0; i < rows; i++)
            for (uint j = 0; j < cols; j++)
                if (grid [i, j] == 0)
                    return false;
        return true;
    }

    internal void clear ()
    {
        _clear (ref _grid);
    }
    private static void _clear (ref uint8 [,] grid)
    {
        uint rows = grid.length [0];
        uint cols = grid.length [1];

        for (uint i = 0; i < rows; i++)
            for (uint j = 0; j < cols; j++)
                grid [i, j] = 0;
    }

    internal long get_score ()
    {
        return _get_score (ref _grid);
    }
    private static long _get_score (ref uint8 [,] grid)
    {
        long score = 0;

        uint rows = grid.length [0];
        uint cols = grid.length [1];

        for (uint i = 0; i < rows; i++)
            for (uint j = 0; j < cols; j++)
                score += _calculate_score_value (grid [i, j]);
        return score;
    }
    private static inline long _calculate_score_value (uint8 tile_value)
    {
        if (tile_value < 2)
            return 0;
        return (long) (Math.pow (2, tile_value) * (tile_value - 1));
    }

    /*\
    * * getting values
    \*/

    internal Grid clone ()
    {
        Grid grid = new Grid (_rows, _cols);
        grid._grid = _grid;
        grid._target_value = _target_value;
        grid._target_value_reached = _target_value_reached;

        return grid;
    }

    internal new uint8 get (int row, int col)    // allows calling "uint val = _grid [i, j];" in game.vala
    {
        if ((row >= _rows) || (col >= _cols))
            return 0;

        return _grid [row, col];
    }

    /*\
    * * saving
    \*/

    internal string save ()
    {
        string ret_string = @"$_rows $_cols\n";
        _convert_to_string (ref _grid, ref ret_string);
        ret_string += _get_score (ref _grid).to_string ();  // historical, not
        ret_string += "\n";                                // used when loading
        return ret_string;
    }

    internal string to_string ()                // for debug, in @"$_grid" strings
    {
        string ret_string = "\n";
        _convert_to_string (ref _grid, ref ret_string);
        return ret_string;
    }

    private static void _convert_to_string (ref uint8 [,] grid, ref string ret_string)
    {
        uint rows = grid.length [0];
        uint cols = grid.length [1];

        for (uint i = 0; i < rows; i++)
        {
            for (uint j = 0; j < cols; j++)
            {
                uint64 val;
                if (grid [i, j] == 0)
                    val = 0;
                else
                    val = (uint64) Math.pow (2, grid [i, j]);
                ret_string += "%llu%s".printf (val, (j == (cols - 1)) ? "\n" : " ");
            }
        }
    }

    /*\
    * * restoring
    \*/

    internal bool load (ref string content)
    {
        uint8 [,] grid = {{}};   // garbage
        if (!_load_from_string (ref content, ref grid))
            return false;

        _rows = grid.length [0];
        _cols = grid.length [1];
        _grid = grid;
        return true;
    }

    private static bool _load_from_string (ref string content,
                                           ref uint8 [,] grid)
    {
        string [] lines = content.split ("\n");

        // check that at least it contains 3 rows: size, content, score
        if (lines.length < 4)
            return false;

        string [] tokens = lines [0].split (" ");
        if (tokens.length != 2)
            return false;

        uint64 number_64;
        // rows
        if (!uint64.try_parse (tokens [0], out number_64))
            return false;
        if ((number_64 == 0) || (number_64 > 9))
            return false;
        int rows = (int) number_64;
        // cols
        if (!uint64.try_parse (tokens [1], out number_64))
            return false;
        if ((number_64 == 0) || (number_64 > 9))
            return false;
        int cols = (int) number_64;

        if (Application.is_disallowed_grid_size (ref rows, ref cols))
            return false;
        // number of rows + 1 for size + 1 for score; maybe an empty line at end
        if (lines.length < rows + 2)
            return false;

        grid = new uint8 [rows, cols];

        for (uint i = 0; i < rows; i++)
        {
            tokens = lines [i + 1].split (" ");
            // we do need to be strict here
            if (tokens.length != cols)
                return false;

            for (uint j = 0; j < cols; j++)
            {
                if (!uint64.try_parse (tokens [j], out number_64))
                    return false;
                uint8 number;
                if (!_convert_tile_number (ref number_64, out number))
                    return false;
                grid [i, j] = number;
            }
        }

        return true;
    }

    private static inline bool _convert_tile_number (ref uint64 number_64,
                                                     out uint8 number)
    {
        if (number_64 == 0)
        {
            number = 0;
            return true;
        }
        for (number = 1; number <= 81; number++)
            if (number_64 == (uint64) Math.pow (2, number))
                return true;

        return false;
    }
}

private struct GridPosition
{
    public int row;
    public int col;

    internal string to_string ()
    {
        return @"($row,$col)";
    }
}

private struct TileMovement
{
    public GridPosition from;
    public GridPosition to;
}

private struct Tile
{
    public GridPosition pos;
    public uint8 val;
}
