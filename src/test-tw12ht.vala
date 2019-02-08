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
        return Test.run ();
    }

    private static void test_tests ()
    {
        assert_true (1 + 1 == 2);
    }

    /*\
    * * tests
    \*/
}
