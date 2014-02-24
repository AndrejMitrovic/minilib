/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.math;

import std.math;

/** Convert radians to degrees. */
double toRadians(double degrees)
{
    return degrees * (PI / 180.0);
}

/** Convert degrees to radians. */
double toDegrees(double radians)
{
    return radians * (180.0 / PI);
}
