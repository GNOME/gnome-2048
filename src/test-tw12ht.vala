/* Copyright (C) 2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

private class TestTw12ht : Object
{
    private static int main (string [] args)
    {
        Test.init (ref args);
        Test.add_func ("/Tw12ht/test tests",
                                test_tests);
        Test.add_func ("/Tw12ht/test full game",
                                test_full_game);
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

    private static void test_full_grid (int rows, int cols)
    {
        TestGrid grid = new TestGrid (rows, cols);
        for (int i = 0; i < rows * cols; i++)
        {
            Tile unused;
            grid.new_tile (out unused);
        }

        assert_true (grid.grid_is_full ());

        for (int i = 0; i < rows; i++)
            for (int j = 0; j < cols; j++)
                assert_true (grid [i, j] == 1);
    }
}
