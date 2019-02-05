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
    private uint [,] _grid;

    public int rows { internal get; protected construct; }
    public int cols { internal get; protected construct; }

    internal uint target_value          { internal get; internal set; default = 0; }
    internal bool target_value_reached  { internal get; internal set; default = false; }

    construct
    {
        _grid = new uint [rows, cols];
        clear ();
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
        if (_grid_is_full ())
            assert_not_reached ();

        GridPosition pos = { 0, 0 }; // TODO report bug: garbage init needed
        do { _generate_random_position (rows, cols, out pos); }
        while (_grid [pos.row, pos.col] != 0);

        _grid [pos.row, pos.col] = 2;
        tile = { pos, /* tile value */ 2 };
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

        uint max_changed = 0;
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
        if (max_changed >= target_value)
            target_value_reached = true;
    }

    private static void _move_down (int cols,
                                    int rows,
                                ref uint max_changed,
                                ref uint [,] grid,
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
                uint val = grid [cur.row, cur.col];

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
                    uint k_val = grid [k, cur.col];

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
                              ref uint max_changed,
                              ref uint [,] grid,
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
                uint val = grid [cur.row, cur.col];

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
                    uint k_val = grid [k, cur.col];

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
                                ref uint max_changed,
                                ref uint [,] grid,
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
                uint val = grid [cur.row, cur.col];

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
                    uint k_val = grid [cur.row, k];

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
                                 ref uint max_changed,
                                 ref uint [,] grid,
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
                uint val = grid [cur.row, cur.col];

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
                    uint k_val = grid [cur.row, k];

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
                                        ref uint [,] grid,
                                        ref uint val,
                                        ref uint max_changed)
    {
        debug (@"matching tile found at $match");

        TileMovement mov = { cur, free };
        to_hide.add (mov);
        mov = { match, free };
        to_hide.add (mov);

        uint new_val = 2 * val;
        Tile tile = { free, new_val };
        to_show.add (tile);

        grid [cur.row, cur.col] = 0;
        grid [match.row, match.col] = 0;
        grid [free.row, free.col] = new_val;
        if (max_changed < new_val)
            max_changed = new_val;
    }

    private static void _move_to_end (ref Gee.LinkedList<TileMovement?> to_move,
                                      ref GridPosition cur,
                                      ref GridPosition free,
                                      ref uint [,] grid,
                                      ref uint val)
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
        if (!_grid_is_full ())
            return false;

        for (int i = 0; i < _rows; i++)
        {
            for (int j = 0; j < _cols; j++)
            {
                uint val = _grid [i, j];

                if (i < (_rows - 1) && val == _grid [i+1, j])
                    return false;

                if (j < (_cols - 1) && val == _grid [i, j+1])
                    return false;
            }
        }

        return true;
    }

    private bool _grid_is_full ()
    {
        for (uint i = 0; i < _rows; i++)
            for (uint j = 0; j < _cols; j++)
                if (_grid [i, j] == 0)
                    return false;

        return true;
    }

    internal void clear ()
    {
        for (uint i = 0; i < _grid.length [0]; i++)
            for (uint j = 0; j < _grid.length [1]; j++)
                _grid [i, j] = 0;
    }

    /*\
    * * saving and restoring
    \*/

    internal Grid clone ()
    {
        Grid grid = new Grid (_rows, _cols);
        grid._grid = _grid;
        grid._target_value = _target_value;
        grid._target_value_reached = _target_value_reached;

        return grid;
    }

    internal new uint get (int row, int col)    // allows calling "uint val = _grid [i, j];" in game.vala
    {
        if ((row >= _rows) || (col >= _cols))
            return 0;

        return _grid [row, col];
    }

    internal string save ()
    {
        string ret = "";

        ret += _rows.to_string () + " ";
        ret += _cols.to_string () + "\n";

        ret += _convert_to_string ();

        return ret;
    }

    internal bool load (string content)
    {
        return _load_from_string (content);
    }

    internal string to_string ()
    {
        string ret = "\n";
        ret += _convert_to_string ();
        return ret;
    }

    private string _convert_to_string ()
    {
        string ret = "";

        for (uint i = 0; i < _rows; i++)
            for (uint j = 0; j < _cols; j++)
                ret += "%u%s".printf (_grid[i,j], (j == (_cols-1)) ? "\n" : " ");

        return ret;
    }

    private bool _load_from_string (string contents)
    {
        int rows = 0;
        int cols = 0;
        string [] lines;
        string [] tokens;
        uint [,] grid;

        lines = contents.split ("\n");

        // check that at least it contains 3 rows: size, content, score
        if (lines.length < 4)
            return false;

        tokens = lines[0].split (" ");
        if (tokens.length != 2)
            return false;

        rows = int.parse (tokens[0]);
        cols = int.parse (tokens[1]);

        if ((rows < 1) || (cols < 1) || (rows > 9) || (cols > 9))
            return false;
        if (Application.is_disallowed_grid_size (ref rows, ref cols))
            return false;
        // we don't need to be strict here
        if (lines.length < rows + 1)
            return false;

        grid = new uint [rows, cols];

        for (int i = 0; i < rows; i++)
        {
            tokens = lines [i + 1].split (" ");
            // we do need to be strict here
            if (tokens.length != cols)
                return false;

            for (int j = 0; j < cols; j++)
                grid [i, j] = int.parse (tokens [j]);
        }

        _rows = rows;
        _cols = cols;
        _grid = grid;

        return true;
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
    public uint val;
}
