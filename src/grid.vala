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

    construct
    {
        _grid = new uint [rows, cols];
        clear ();
    }

    internal Grid (int rows, int cols)
    {
        Object (rows: rows, cols: cols);
    }

    public int rows { internal get; protected construct; }
    public int cols { internal get; protected construct; }

    internal uint target_value          { internal get; internal set; default = 0; }
    internal bool target_value_reached  { internal get; internal set; default = false; }

    internal Grid clone ()
    {
        Grid grid = new Grid (_rows, _cols);
        grid._grid = _grid;
        grid._target_value = _target_value;
        grid._target_value_reached = _target_value_reached;

        return grid;
    }

    internal void clear ()
    {
        for (uint i = 0; i < _grid.length [0]; i++)
            for (uint j = 0; j < _grid.length [1]; j++)
                _grid [i, j] = 0;
    }

    internal bool new_tile (out Tile tile)
    {
        GridPosition pos = { 0, 0 };
        uint val;
        tile = { pos, 0 };

        if (_grid_is_full ())
            return false;

        val = 2;

        while (true)
        {
            pos = _random_position ();

            if (_grid[pos.row,pos.col] == 0)
            {
                _grid[pos.row,pos.col] = val;
                _check_target_value_reached (val);
                tile = { pos, val };
                return true;
            }
        }
    }

    internal void move_down (Gee.LinkedList<TileMovement?> to_move,
                             Gee.LinkedList<TileMovement?> to_hide,
                             Gee.LinkedList<Tile?> to_show)
    {
        to_move.clear ();
        to_hide.clear ();
        to_show.clear ();

        for (int i = 0; i < _cols; i++)
        {
            GridPosition free = { _rows, i };

            for (int j = 0; j < _rows; j++)
            {
                int row = _rows - j - 1;
                GridPosition cur = { row, i };
                uint val = _grid[cur.row,cur.col];

                if (val == 0)
                {
                    if (free.row == _rows)
                        free.row = row;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = row - 1; k >= 0; k--)
                {
                    uint k_val = _grid[k,cur.col];

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
                    debug (@"matching tile found at $match");

                    if (free.row == _rows)
                        free.row = row; // temporarily

                    TileMovement mov = { cur, free };
                    to_hide.add (mov);
                    mov = { match, free };
                    to_hide.add (mov);

                    Tile tile = { free, val*2 };
                    to_show.add (tile);

                    _grid[cur.row,cur.col] = 0;
                    _grid[match.row,match.col] = 0;
                    _grid[free.row,free.col] = val*2;
                    _check_target_value_reached (val*2);

                    free.row--;
                }
                else if (free.row != _rows)
                {
                    debug (@"moving $cur to $free");

                    TileMovement mov = { cur, free };
                    to_move.add (mov);

                    _grid[cur.row,cur.col] = 0;
                    _grid[free.row,free.col] = val;

                    free.row--;
                }
            }
        }
    }

    internal void move_up (Gee.LinkedList<TileMovement?> to_move,
                           Gee.LinkedList<TileMovement?> to_hide,
                           Gee.LinkedList<Tile?> to_show)
    {
        to_move.clear ();
        to_hide.clear ();
        to_show.clear ();

        for (int i = 0; i < _cols; i++)
        {
            GridPosition free = { -1, i };

            for (int j = 0; j < _rows; j++)
            {
                int row = j;
                GridPosition cur = { row, i };
                uint val = _grid[cur.row,cur.col];

                if (val == 0)
                {
                    if (free.row == -1)
                        free.row = row;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = row + 1; k < _rows; k++)
                {
                    uint k_val = _grid[k,cur.col];

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
                    debug (@"matching tile found at $match");

                    if (free.row == -1)
                        free.row = row; // temporarily

                    TileMovement mov = { cur, free };
                    to_hide.add (mov);
                    mov = { match, free };
                    to_hide.add (mov);

                    Tile tile = { free, val*2 };
                    to_show.add (tile);

                    _grid[cur.row,cur.col] = 0;
                    _grid[match.row,match.col] = 0;
                    _grid[free.row,free.col] = val*2;
                    _check_target_value_reached (val*2);

                    free.row++;
                }
                else if (free.row != -1)
                {
                    debug (@"moving $cur to $free");

                    TileMovement mov = { cur, free };
                    to_move.add (mov);

                    _grid[cur.row,cur.col] = 0;
                    _grid[free.row,free.col] = val;

                    free.row++;
                }
            }
        }
    }

    internal void move_left (Gee.LinkedList<TileMovement?> to_move,
                             Gee.LinkedList<TileMovement?> to_hide,
                             Gee.LinkedList<Tile?> to_show)
    {
        to_move.clear ();
        to_hide.clear ();
        to_show.clear ();

        for (int i = 0; i < _rows; i++)
        {
            GridPosition free = { i, -1 };

            for (int j = 0; j < _cols; j++)
            {
                int col = j;
                GridPosition cur = { i, col };
                uint val = _grid[cur.row,cur.col];

                if (val == 0)
                {
                    if (free.col == -1)
                        free.col = col;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = col + 1; k < _cols; k++)
                {
                    uint k_val = _grid[cur.row,k];

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
                    debug (@"matching tile found at $match");

                    if (free.col == -1)
                        free.col = col; // temporarily

                    TileMovement mov = { cur, free };
                    to_hide.add (mov);
                    mov = { match, free };
                    to_hide.add (mov);

                    Tile tile = { free, val*2 };
                    to_show.add (tile);

                    _grid[cur.row,cur.col] = 0;
                    _grid[match.row,match.col] = 0;
                    _grid[free.row,free.col] = val*2;
                    _check_target_value_reached (val*2);

                    free.col++;
                }
                else if (free.col != -1)
                {
                    debug (@"moving $cur to $free");

                    TileMovement mov = { cur, free };
                    to_move.add (mov);

                    _grid[cur.row,cur.col] = 0;
                    _grid[free.row,free.col] = val;

                    free.col++;
                }
            }
        }
    }

    internal void move_right (Gee.LinkedList<TileMovement?> to_move,
                              Gee.LinkedList<TileMovement?> to_hide,
                              Gee.LinkedList<Tile?> to_show)
    {
        to_move.clear ();
        to_hide.clear ();
        to_show.clear ();

        for (int i = 0; i < _rows; i++)
        {
            GridPosition free = { i, _cols };

            for (int j = 0; j < _cols; j++)
            {
                int col = _cols - j - 1;
                GridPosition cur = { i, col };
                uint val = _grid[cur.row,cur.col];

                if (val == 0)
                {
                    if (free.col == _cols)
                        free.col = col;
                    continue;
                }

                // search for matches
                GridPosition match = { 0, 0 };
                bool has_match = false;
                for (int k = col - 1; k >= 0; k--)
                {
                    uint k_val = _grid[cur.row,k];

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
                    debug (@"matching tile found at $match");

                    if (free.col == _cols)
                        free.col = col; // temporarily

                    TileMovement mov = { cur, free };
                    to_hide.add (mov);
                    mov = { match, free };
                    to_hide.add (mov);

                    Tile tile = { free, val*2 };
                    to_show.add (tile);

                    _grid[cur.row,cur.col] = 0;
                    _grid[match.row,match.col] = 0;
                    _grid[free.row,free.col] = val*2;
                    _check_target_value_reached (val*2);

                    free.col--;
                }
                else if (free.col != _cols)
                {
                    debug (@"moving $cur to $free");

                    TileMovement mov = { cur, free };
                    to_move.add (mov);

                    _grid[cur.row,cur.col] = 0;
                    _grid[free.row,free.col] = val;

                    free.col--;
                }
            }
        }
    }

    internal bool is_finished ()
    {
        if (!_grid_is_full ())
            return false;

        for (int i = 0; i < _rows; i++)
        {
            for (int j = 0; j < _cols; j++)
            {
                uint val = _grid[i,j];

                if (i < (_rows - 1) && val == _grid[i+1,j])
                    return false;

                if (j < (_cols - 1) && val == _grid[i,j+1])
                    return false;
            }
        }

        return true;
    }

    internal new uint get (int row, int col)
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

        if ((rows < 1) || (cols < 1))
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

    private bool _grid_is_full ()
    {
        for (uint i = 0; i < _rows; i++)
            for (uint j = 0; j < _cols; j++)
                if (_grid[i,j] == 0)
                    return false;

        return true;
    }

    private GridPosition _random_position ()
    {
        GridPosition ret = { Random.int_range (0, (int)_rows),
                             Random.int_range (0, (int)_cols) };

        return ret;
    }

    private void _check_target_value_reached (uint val)
    {
        if (target_value != 0 && val == target_value)
            target_value_reached = true;
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
