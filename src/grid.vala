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

public class Grid : GLib.Object
{
  private int _n_rows;
  private int _n_cols;

  private uint[,] _grid;

  public Grid (int n_rows, int n_cols)
  {
    Object ();

    _n_rows = n_rows;
    _n_cols = n_cols;

    _grid = new uint[_n_rows, _n_cols];
  }

  construct
  {
    clear ();
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

    for (int i = 0; i < _n_cols; i++) {
      free = { _n_rows, i };

      for (int j = 0; j < _n_rows; j++) {
        row = _n_rows - j - 1;
        cur = { row, i };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.row == _n_rows) {
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

          if (free.row == _n_rows) {
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

          free.row--;
        } else if (free.row != _n_rows) {
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

    for (int i = 0; i < _n_cols; i++) {
      free = { -1, i };

      for (int j = 0; j < _n_rows; j++) {
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
        for (int k = row + 1; k < _n_rows; k++) {
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

    for (int i = 0; i < _n_rows; i++) {
      free = { i, -1 };

      for (int j = 0; j < _n_cols; j++) {
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
        for (int k = col + 1; k < _n_rows; k++) {
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

    for (int i = 0; i < _n_rows; i++) {
      free = { i, _n_cols };

      for (int j = 0; j < _n_cols; j++) {
        col = _n_cols - j - 1;
        cur = { i, col };
        val = _grid[cur.row,cur.col];

        if (val == 0) {
          if (free.col == _n_cols) {
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

          if (free.col == _n_cols) {
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

          free.col--;
        } else if (free.col != _n_cols) {
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
      for (int i = 0; i < _n_rows; i++) {
        for (int j = 0; j < _n_cols; j++) {
          val = _grid[i,j];

          if (i < (_n_rows - 1))
            if (val == _grid[i+1,j])
              return false;

          if (j < (_n_cols - 1))
            if (val == _grid[i,j+1])
              return false;
        }
      }
    }

    return true;
  }

  public string to_string ()
  {
    string ret = "";

    for (uint i = 0; i < _n_rows; i++) {
      ret += "\n";
      for (uint j = 0; j < _n_cols; j++) {
        ret += " " + _grid[i,j].to_string () + " ";
      }
    }

    return ret;
  }

  private bool _grid_is_full ()
  {
    for (uint i = 0; i < _n_rows; i++) {
      for (uint j = 0; j < _n_cols; j++) {
        if (_grid[i,j] == 0) {
          return false;
        }
      }
    }

    return true;
  }

  private GridPosition _random_position ()
  {
    GridPosition ret = { Random.int_range (0, (int)_n_rows),
                         Random.int_range (0, (int)_n_cols) };

    return ret;
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
