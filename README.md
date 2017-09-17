# DateTime

DateTime functions for nim

A collection of some functions to do Date/Time calculations inspired by various sources:

- the [datetime](https://docs.python.org/3/library/datetime.html) module from Python
- CommonLisp's [calendrica-3.0.cl](https://github.com/espinielli/pycalcal) ported to Python and to [Nim](https://github.com/skilchen/nimcalcal)
- the [times](https://nim-lang.org/docs/times.html) module from Nim's standard library
- the [rfc3339](https://github.com/skrylar/rfc3339) module from Github

This module provides simple types and procedures to represent date/time values and to perform calculations with them, such as absolute and relative differences between DateTime instances and TimeDeltas or TimeIntervals.

The parsing and formatting procedures are from Nim's standard library and from the rfc3339 module. Additionally it implements a simple version of strftime inspired mainly by the [LuaDate](https://github.com/wscherphof/lua-date) module and Python [strftime](https://docs.python.org/3/library/datetime.html#strftime-strptime-behavior) function.

My main goals are:

- epochTime() is the only platform specific date/time functions in use.
- dealing with timezone offsets is the responsibility of the user of this module. it allows you to store an offset to UTC and a DST flag but no attempt is made to detect these things from the running platform.
- hopefully correct implementation of the used algorithms.
