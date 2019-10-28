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

private class TestTw12ht : Object
{
    private static int main (string [] args)
    {
        Test.init (ref args);
        Test.add_func ("/Tw12ht/test tests",
                                test_tests);
        Test.add_func ("/Tw12ht/test full game",
                                test_full_game);
        Test.add_func ("/Tw12ht/test load game",
                                test_load_game);
        return Test.run ();
    }

    private static void test_tests ()
    {
        assert_true (1 + 1 == 2);
    }

    /*\
    * * test full game
    \*/

    private static void test_full_game ()
    {
        test_full_grid (3, 3);
        test_full_grid (4, 4);
        test_full_grid (5, 5);
        test_full_grid (3, 5);
        test_full_grid (4, 3);
    }

    private static void test_full_grid (uint8 rows, uint8 cols)
    {
        TestGrid grid = new TestGrid (rows, cols);
        test_new_grid_size (ref grid, rows, cols);

        for (uint8 i = 0; i < rows * cols; i++)
            test_tile_creation (ref grid);

        test_grid_fullness (ref grid);
        test_grid_clearing (ref grid);
    }

    private static void test_new_grid_size (ref TestGrid grid, uint8 rows, uint8 cols)
    {
        assert_true (grid.rows == rows);
        assert_true (grid.cols == cols);
    }

    private static void test_tile_creation (ref TestGrid grid)
    {
        uint8 rows = grid.rows;
        uint8 cols = grid.cols;

        Tile tile;
        grid.new_tile (out tile);

        assert_true (tile.val == 1);
        assert_true (tile.pos.row >= 0);
        assert_true (tile.pos.row < rows);
        assert_true (tile.pos.col >= 0);
        assert_true (tile.pos.col < cols);
    }

    private static void test_grid_fullness (ref TestGrid grid)
    {
        uint8 rows = grid.rows;
        uint8 cols = grid.cols;

        assert_true (grid.grid_is_full ());

        for (uint8 i = 0; i < rows; i++)
            for (uint8 j = 0; j < cols; j++)
                assert_true (grid [i, j] == 1);
    }

    private static void test_grid_clearing (ref TestGrid grid)
    {
        uint8 rows = grid.rows;
        uint8 cols = grid.cols;

        grid.clear ();

        for (uint8 i = 0; i < rows; i++)
            for (uint8 j = 0; j < cols; j++)
                assert_true (grid [i, j] == 0);
    }

    /*\
    * * test load game
    \*/

    private static void test_load_game ()
    {
        uint8 rows, cols;
        string old_content, new_content;
        bool loaded;

        // correct square game
        old_content = "2 2\n0 2\n2 4\n4\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == true && rows == 2 && cols == 2 && new_content == old_content);

        // incorrect: inverted rows & cols numbers
        old_content = "3 2\n0 2 0\n0 2 4\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // correct non-square game
        old_content = "3 2\n0 2\n0 4\n4 2\n8\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == true && rows == 3 && cols == 2 && new_content == old_content);

        // incorrect: bad tile 3
        old_content = "3 2\n0 2\n0 4\n4 3\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // incorrect: bad tile -2
        old_content = "3 2\n0 2\n0 4\n4 -2\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // incorrect: bad rows number 10
        old_content = "10 2\n0 2\n0 4\n4 2\n0 2\n0 4\n4 2\n0 2\n0 4\n4 2\n0 1\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // incorrect: bad cols number 10
        old_content = "2 10\n0 2 4 8 2 4 8 2 4 8\n0 4 0 2 0 4 0 2 0 8\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // incorrect: second row not matching cols number
        old_content = "3 2\n0 2\n0 4 2\n4 2\n-42\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == false);

        // incorrect score
        old_content = "3 2\n0 2\n0 4\n8 2\n16\n";
        test_load_grid (ref old_content, out loaded, out rows, out cols, out new_content);
        assert_true (loaded == true && rows == 3 && cols == 2);
        assert_true (new_content != old_content);
    }

    private static void test_load_grid (ref string  old_content,
                                        out bool    loaded,
                                        out uint8   rows,
                                        out uint8   cols,
                                        out string  new_content)
    {
        Grid grid = new Grid (1, 1);   // TODO transform load into a constructor
        loaded = grid.load (ref old_content);

        rows        = loaded ? grid.rows    : uint8.MAX;
        cols        = loaded ? grid.cols    : uint8.MAX;
        new_content = loaded ? grid.save () : "";
    }
}

private class TestGrid : Grid
{
    internal TestGrid (uint8 rows, uint8 cols)
    {
        Object (rows: rows, cols: cols);
    }

    internal bool grid_is_full ()
    {
        return _grid_is_full (ref _grid);
    }
}
