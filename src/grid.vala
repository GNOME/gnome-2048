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

public class Grid : GLib.Object
{
  private uint[,] _grid;

  public Grid (int rows, int cols)
  {
    Object (rows: rows, cols: cols);

    _grid = new uint[rows, cols];
    clear ();
    _target_value = 0;
  }

  public int rows {
    get; set;
  }

  public int cols {
    get; set;
  }

  public uint target_value {
    get; set;
  }

  public bool target_value_reached {
    get; set;
  }

  public void clear ()
  {
    for (uint i = 0; i < _grid.length[0]; i++) {
      for (uint j = 0; j < _grid.length[1]; j++) {
        _grid[i,j] = 0;
      }
    }
  }

  public bool new_tile (out Tile tile)
  {
    GridPosition pos = { 0, 0 };
    uint val;
    tile = { pos, 0 };

    if (_grid_is_full ()) {
      return false;
    }

    val = 2;

    while (true) {
      pos = _random_position ();

      if (_grid[pos.row,pos.col] == 0) {
        _grid[pos.row,pos.col] = val;
        _check_target_value_reached (val);
        tile = { pos, val };
        return true;
      }
    }
  }

  public void move_down (Gee.LinkedList<TileMovement?> to_move,
                         Gee.LinkedList<TileMovement?> to_hide,
                         Gee.LinkedList<Tile?> to_show)
  {
    GridPosition free;
    GridPosition cur;
    GridPosition match;
    bool has_match;
    int row;
    uint val;
    TileMovement mov;
    Tile tile;

    to_move.clear ();
    to_hide.clear ();
    to_show.clear ();

    for (int i = 0; i < _cols; i++) {
      free = { _rows, i };

      for (int j = 0; j < _rows; j++) {
        row = _rows - j - 1;
        cur = { row, i };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.row == _rows) {
            free.row = row;
          }
          continue;
        }

        // search for matches
        match = { 0, 0 };
        has_match = false;
        for (int k = row - 1; k >= 0; k--) {
          uint k_val = _grid[k,cur.col];

          if (k_val != 0) {
            if (k_val == val) {
              has_match = true;
              match = { k, cur.col };
            }
            break;
          }
        }

        if (has_match) {
          debug (@"matching tile found at $match");

          if (free.row == _rows) {
            free.row = row; // temporarily
          }
          mov = { cur, free };
          to_hide.add (mov);
          mov = { match, free };
          to_hide.add (mov);

          tile = { free, val*2 };
          to_show.add (tile);

          _grid[cur.row,cur.col] = 0;
          _grid[match.row,match.col] = 0;
          _grid[free.row,free.col] = val*2;
          _check_target_value_reached (val*2);

          free.row--;
        } else if (free.row != _rows) {
          debug (@"moving $cur to $free");

          mov = { cur, free };
          to_move.add (mov);

          _grid[cur.row,cur.col] = 0;
          _grid[free.row,free.col] = val;

          free.row--;
        }
      }
    }
  }

  public void move_up (Gee.LinkedList<TileMovement?> to_move,
                       Gee.LinkedList<TileMovement?> to_hide,
                       Gee.LinkedList<Tile?> to_show)
  {
    GridPosition free;
    GridPosition cur;
    GridPosition match;
    bool has_match;
    int row;
    uint val;
    TileMovement mov;
    Tile tile;

    to_move.clear ();
    to_hide.clear ();
    to_show.clear ();

    for (int i = 0; i < _cols; i++) {
      free = { -1, i };

      for (int j = 0; j < _rows; j++) {
        row = j;
        cur = { row, i };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.row == -1) {
            free.row = row;
          }
          continue;
        }

        // search for matches
        match = { 0, 0 };
        has_match = false;
        for (int k = row + 1; k < _rows; k++) {
          uint k_val = _grid[k,cur.col];

          if (k_val != 0) {
            if (k_val == val) {
              has_match = true;
              match = { k, cur.col };
            }
            break;
          }
        }

        if (has_match) {
          debug (@"matching tile found at $match");

          if (free.row == -1) {
            free.row = row; // temporarily
          }
          mov = { cur, free };
          to_hide.add (mov);
          mov = { match, free };
          to_hide.add (mov);

          tile = { free, val*2 };
          to_show.add (tile);

          _grid[cur.row,cur.col] = 0;
          _grid[match.row,match.col] = 0;
          _grid[free.row,free.col] = val*2;
          _check_target_value_reached (val*2);

          free.row++;
        } else if (free.row != -1) {
          debug (@"moving $cur to $free");

          mov = { cur, free };
          to_move.add (mov);

          _grid[cur.row,cur.col] = 0;
          _grid[free.row,free.col] = val;

          free.row++;
        }
      }
    }
  }

  public void move_left (Gee.LinkedList<TileMovement?> to_move,
                         Gee.LinkedList<TileMovement?> to_hide,
                         Gee.LinkedList<Tile?> to_show)
  {
    GridPosition free;
    GridPosition cur;
    GridPosition match;
    bool has_match;
    int col;
    uint val;
    TileMovement mov;
    Tile tile;

    to_move.clear ();
    to_hide.clear ();
    to_show.clear ();

    for (int i = 0; i < _rows; i++) {
      free = { i, -1 };

      for (int j = 0; j < _cols; j++) {
        col = j;
        cur = { i, col };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.col == -1) {
            free.col = col;
          }
          continue;
        }

        // search for matches
        match = { 0, 0 };
        has_match = false;
        for (int k = col + 1; k < _rows; k++) {
          uint k_val = _grid[cur.row,k];

          if (k_val != 0) {
            if (k_val == val) {
              has_match = true;
              match = { cur.row, k };
            }
            break;
          }
        }

        if (has_match) {
          debug (@"matching tile found at $match");

          if (free.col == -1) {
            free.col = col; // temporarily
          }
          mov = { cur, free };
          to_hide.add (mov);
          mov = { match, free };
          to_hide.add (mov);

          tile = { free, val*2 };
          to_show.add (tile);

          _grid[cur.row,cur.col] = 0;
          _grid[match.row,match.col] = 0;
          _grid[free.row,free.col] = val*2;
          _check_target_value_reached (val*2);

          free.col++;
        } else if (free.col != -1) {
          debug (@"moving $cur to $free");

          mov = { cur, free };
          to_move.add (mov);

          _grid[cur.row,cur.col] = 0;
          _grid[free.row,free.col] = val;

          free.col++;
        }
      }
    }
  }

  public void move_right (Gee.LinkedList<TileMovement?> to_move,
                          Gee.LinkedList<TileMovement?> to_hide,
                          Gee.LinkedList<Tile?> to_show)
  {
    GridPosition free;
    GridPosition cur;
    GridPosition match;
    bool has_match;
    int col;
    uint val;
    TileMovement mov;
    Tile tile;

    to_move.clear ();
    to_hide.clear ();
    to_show.clear ();

    for (int i = 0; i < _rows; i++) {
      free = { i, _cols };

      for (int j = 0; j < _cols; j++) {
        col = _cols - j - 1;
        cur = { i, col };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.col == _cols) {
            free.col = col;
          }
          continue;
        }

        // search for matches
        match = { 0, 0 };
        has_match = false;
        for (int k = col - 1; k >= 0; k--) {
          uint k_val = _grid[cur.row,k];

          if (k_val != 0) {
            if (k_val == val) {
              has_match = true;
              match = { cur.row, k };
            }
            break;
          }
        }

        if (has_match) {
          debug (@"matching tile found at $match");

          if (free.col == _cols) {
            free.col = col; // temporarily
          }
          mov = { cur, free };
          to_hide.add (mov);
          mov = { match, free };
          to_hide.add (mov);

          tile = { free, val*2 };
          to_show.add (tile);

          _grid[cur.row,cur.col] = 0;
          _grid[match.row,match.col] = 0;
          _grid[free.row,free.col] = val*2;
          _check_target_value_reached (val*2);

          free.col--;
        } else if (free.col != _cols) {
          debug (@"moving $cur to $free");

          mov = { cur, free };
          to_move.add (mov);

          _grid[cur.row,cur.col] = 0;
          _grid[free.row,free.col] = val;

          free.col--;
        }
      }
    }
  }

  public bool is_finished ()
  {
    uint val;

    if (!_grid_is_full ())
      return false;
    else {
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          val = _grid[i,j];

          if (i < (_rows - 1))
            if (val == _grid[i+1,j])
              return false;

          if (j < (_cols - 1))
            if (val == _grid[i,j+1])
              return false;
        }
      }
    }

    return true;
  }

  public new uint get (int row, int col)
  {
    if ((row >= _rows) || (col >= _cols))
      return 0;

    return _grid[row,col];
  }

  public string save ()
  {
    string ret = "";

    ret += _rows.to_string () + " ";
    ret += _cols.to_string () + "\n";

    ret += _convert_to_string ();

    return ret;
  }

  public bool load (string content)
  {
    return _load_from_string (content);
  }

  public string to_string ()
  {
    string ret = "\n";
    ret += _convert_to_string ();
    return ret;
  }

  private string _convert_to_string ()
  {
    string ret = "";

    for (uint i = 0; i < _rows; i++) {
      for (uint j = 0; j < _cols; j++) {
        ret += "%u%s".printf (_grid[i,j], (j == (_cols-1)) ? "\n" : " ");
      }
    }

    return ret;
  }

  private bool _load_from_string (string contents)
  {
    int rows = 0;
    int cols = 0;
    string[] lines;
    string[] tokens;
    uint[,] grid;

    lines = contents.split ("\n");

    // check that at least it contains 2 rows
    if (lines.length < 3)
      return false;

    tokens = lines[0].split (" ");
    if (tokens.length != 2)
      return false;

    rows = int.parse (tokens[0]);
    cols = int.parse (tokens[1]);

    if ((rows < 2) || (cols < 2))
      return false;
    // we don't need to be strict here
    if (lines.length < (rows+1))
      return false;

    grid = new uint[rows, cols];

    for (int i = 0; i < rows; i++) {
      tokens = lines[i+1].split (" ");
      // we do need to be strict here
      if (tokens.length != cols)
        return false;

      for (int j = 0; j < cols; j++) {
        grid[i,j] = int.parse (tokens[j]);
      }
    }

    _rows = rows;
    _cols = cols;
    _grid = grid;

    return true;
  }

  private bool _grid_is_full ()
  {
    for (uint i = 0; i < _rows; i++) {
      for (uint j = 0; j < _cols; j++) {
        if (_grid[i,j] == 0) {
          return false;
        }
      }
    }

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
    if (target_value != 0)
      if (val == target_value)
        target_value_reached = true;
  }
}

public struct GridPosition
{
  public uint row;
  public uint col;

  public string to_string ()
  {
    return @"($row,$col)";
  }
}

public struct TileMovement
{
  public GridPosition from;
  public GridPosition to;
}

public struct Tile
{
  public GridPosition pos;
  public uint val;
}
