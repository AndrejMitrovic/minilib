/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.io;

import core.thread;
import core.time;

/**
    Read a character from stdin.
    The function will wait until a character is inputted
    before returning.

    Note: Try https://github.com/robik/ConsoleD for a
    more complete and correct implementation.
*/
char getChar()
{
    version (Posix)
    {
        termios ostate;  /* saved tty state */
        termios nstate;  /* values for editor mode */

        /* Open stdin in raw mode */

        /* Adjust output channel */
        tcgetattr(1, &ostate);  /* save old state */
        tcgetattr(1, &nstate);  /* get base of new state */
        cfmakeraw(&nstate);
        tcsetattr(1, TCSADRAIN, &nstate);  /* set mode */

        // Read character in raw mode
        char result = cast(char)fgetc(stdin);

        // Close
        tcsetattr(1, TCSADRAIN, &ostate);   // return to original mode

        return result;
    }
    else
    version(Windows)
    {
        while (!kbhit())
        {
            Thread.sleep(dur!"msecs"(1));
        }

        return cast(char)getch();
    }
    else static assert(0, "Unsupported OS.");
}

private:

version (Posix)
{
    private
    {
        import core.stdc.stdio;
        import core.sys.posix.termios;
    }

    extern(C) void cfmakeraw(termios* termios_p);
}
else
version (Windows)
{
    extern(C) int kbhit();
    extern(C) int getch();
}
else static assert(0, "Unsupported OS.");
