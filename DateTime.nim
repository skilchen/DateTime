import strutils
import parseutils
import math
from times import epochTime, getLocalTime, fromSeconds, getTimezone

export epochTime, getLocalTime, fromSeconds, getTimezone

const
  OneDay = 86400
  UnixEpochSeconds = 62135683200
  GregorianEpochSeconds = 1 * 24 * 60 * 60


type DateTime* = object
  year*: int
  month*: int
  day*: int
  hour*: int
  minute*: int
  second*: int
  microsecond*: int
  utcoffset*: int
  isDST*: bool
  offsetKnown*: bool

type ISOWeekDate* = object
  year*: int
  week*: int
  weekday*: int

type TimeDelta* = object
  days*: int
  seconds*: int
  microseconds*: int

type TimeInterval* = object ## a time interval
  years*: float64       ## The number of years
  months*: float64      ## The number of months
  days*: float64        ## The number of days
  hours*: float64       ## The number of hours
  minutes*: float64     ## The number of minutes
  seconds*: float64     ## The number of seconds
  microseconds*: float64 ## The number of microseconds

type TimeStamp* = object
  seconds*: float64
  microseconds*: float64


proc ifloor*[T](n: T): int =
  ## Return the whole part of m/n.
  # from math import floor
  return floor(n.float64).int


proc quotient*[T, U](m: T, n:U): int =
  ## Return the whole part of m/n towards negative infinity.
  return ifloor(m.float64 / n.float64)


proc modulo*[T, U](x: T, y: U): U =
  return x.U - quotient(x.U, y.U).U * y

proc fromTimeStamp*(ts: TimeStamp): DateTime {.gcsafe.}
proc toTimeStamp*(dt: DateTime): TimeStamp {.gcsafe.}


proc initDateTime*(year, month, day, hour, minute, second, microsecond: int = 0;
                   utcoffset: int = 0, isDST: bool = false, offsetKnown = false): DateTime =
  result.year = year
  result.month = month
  result.day = day
  result.hour = hour
  result.minute = minute
  result.second = second
  result.microsecond = microsecond
  result.utcoffset = utcoffset
  result.isDST = isDST
  result.offsetKnown = offsetKnown
  result = fromTimeStamp(toTimeStamp(result))


proc initTimeDelta*(days, hours, minutes, seconds, microseconds: float64 = 0): TimeDelta =
  var s: float64 = 0.0
  s += days * OneDay
  s += hours * 3600
  s += minutes * 60
  s += seconds
  s += microseconds / 1e6
  result.days = quotient(s, OneDay.float64)
  result.seconds = int(s - float64(OneDay.float64 * result.days.float64))
  result.microseconds = int(round(modulo(s, 1.0) * 1e6))


proc initTimeStamp*(days, hours, minutes, seconds, microseconds: float64 = 0): TimeStamp =
  var s: float64 = 0.0
  s += days * OneDay
  s += hours * 3600
  s += minutes * 60
  s += seconds
  s += microseconds / 1e6
  result.seconds = int(s).float64
  result.microseconds = round(modulo(s, 1.0) * 1e6)

proc initTimeInterval*(years, months, days, hours, seconds, minutes, microseconds: float64 = 0): TimeInterval =
  ## creates a new ``TimeInterval``.
  ##
  ## You can also use the convenience procedures called ``microseconds``,
  ## ``seconds``, ``minutes``, ``hours``, ``days``, ``months``, and ``years``.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##     let day = initInterval(hours=24
  ##     let tomorrow = now() + day
  ##     echo(tomorrow)
  ##
  var carry: float64 = 0
  result.microseconds = modulo(microseconds, 1e6)
  carry = quotient(microseconds, 1e6).float64
  result.seconds = modulo(carry + seconds, 60).float64
  carry = quotient(carry + seconds, 60).float64
  result.minutes = modulo(carry + minutes, 60).float64
  carry = quotient(carry + minutes, 60).float64
  result.hours = modulo(carry + hours, 24).float64
  carry = quotient(carry + hours, 24).float64
  result.days = carry + days
  result.months = modulo(months, 12).float64
  carry = quotient(months, 12).float64
  result.years = carry + years


proc `+`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Adds two ``TimeInterval`` objects together.
  ##
  var carry: BiggestFloat = 0
  var sm: BiggestFloat = 0
  sm = ti1.microseconds + ti2.microseconds
  result.microseconds = modulo(sm, 1e6)
  carry = quotient(sm, 1e6).float64
  sm = carry + ti1.seconds + ti2.seconds
  result.seconds = modulo(sm, 60).float64
  carry = quotient(sm, 60).float64
  sm = carry + ti1.minutes + ti2.minutes
  result.minutes = modulo(sm, 60).float64
  carry = quotient(sm, 60).float64
  sm = carry + ti1.hours + ti2.hours
  result.hours = modulo(sm, 24).float64
  carry = quotient(sm, 24).float64
  result.days = carry + ti1.days + ti2.days
  sm = ti1.months + ti2.months
  result.months = modulo(sm, 12).float64
  carry = quotient(sm, 12).float64
  result.years = carry + ti1.years + ti2.years


proc `<`(x, y: TimeInterval): bool =
  let xs:float64 = x.years * 366 * 86400 + x.months * 31 * 86400 +
           x.days * 86400 + x. hours * 3600 + x.minutes * 60 +
           x.seconds + float64(quotient(x.microseconds.float64, 1e6))
  let ys:float64 = y.years * 366 * 86400 + y.months * 31 * 86400 +
           y.days * 86400 + y. hours * 3600 + y.minutes * 60 +
           y.seconds + float64(quotient(y.microseconds.float64, 1e6))
  result = xs < ys


proc `-`*(ti: TimeInterval): TimeInterval =
  ## returns a new `TimeInterval` instance with
  ## all its values negated.
  ##
  result = TimeInterval(
    years: -ti.years,
    months: -ti.months,
    days: -ti.days,
    hours: -ti.hours,
    minutes: -ti.minutes,
    seconds: -ti.seconds,
    microseconds: -ti.microseconds,
  )


proc `-`*(ts: TimeStamp): TimeStamp =
  ## returns a new `TimeStamp` instance
  ## with all its values negated.
  ##
  result = TimeStamp(seconds: -ts.seconds,
                     microseconds: -ts.microseconds)


proc `-`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Subtracts TimeInterval ``ti2`` from ``ti1``.
  ##
  ## Time components are compared one-by-one, see output:
  ##
  ## .. code-block:: nim
  ##     let a = fromUnixEpochSeconds(1_000_000_000)
  ##     let b = fromUnixEpochSeconds(1_500_000_000)
  ##     echo b.toTimeInterval - a.toTimeInterval
  ##     # (years: 15, months: 10, days: 5, hours: 0, minutes: 53, seconds: 20, microseconds: 0)
  ##
  var swapped = false
  var (ti1, ti2) = (ti1, ti2)
  if ti1 < ti2:
    swap(ti1, ti2)
    swapped = true
  result = ti1 + (-ti2)
  if swapped:
    result = -result


proc microseconds*(ms: int): TimeInterval {.inline.} =
  ## TimeInterval of `ms` microseconds
  ##
  initTimeInterval(microseconds = ms.float64)


proc seconds*(s: int): TimeInterval {.inline.} =
  ## TimeInterval of `s` seconds
  ##
  ## ``echo now() + 5.second``
  initTimeInterval(seconds = s.float64)


proc minutes*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` minutes
  ##
  ## ``echo now() + 5.minutes``
  initTimeInterval(minutes = m.float64)


proc hours*(h: int): TimeInterval {.inline.} =
  ## TimeInterval of `h` hours
  ##
  ## ``echo now() + 2.hours``
  initTimeInterval(hours = h.float64)


proc days*(d: int): TimeInterval {.inline.} =
  ## TimeInterval of `d` days
  ##
  ## ``echo now() + 2.days``
  initTimeInterval(days = d.float64)


proc months*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` months
  ##
  ## ``echo now() + 2.months``
  initTimeInterval(months = m.float64)


proc years*(y: int): TimeInterval {.inline.} =
  ## TimeInterval of `y` years
  ##
  ## ``echo now() + 2.years``
  initTimeInterval(years = y.float64)


proc totalSeconds*(td: TimeDelta): float64 =
  ## the value of `td` Time difference
  ## expressed as fractional seconds
  ##
  result = float64(td.days * OneDay)
  result += float64(td.seconds)
  result += float64(td.microseconds) / 1e6


proc toTimeStamp*(td: TimeDelta): TimeStamp =
  ## converts `td` Time difference into
  ## a TimeStamp with values seconds and
  ## microseconds. Needed because 64bit
  ## floats have not enough precision to
  ## represet microsecond time resolution.
  ##
  result.seconds = float64(td.days * OneDay)
  result.seconds += td.seconds.float64
  result.microseconds = td.microseconds.float64


proc `$`*(dt: DateTime): string =
  ## get a standard string representation of
  ## `dt` DateTime. Somewhat similar to the
  ## format defined in RFC3339
  ##
  result = ""
  result.add(intToStr(dt.year, 4))
  result.add("-")
  result.add(intToStr(dt.month, 2))
  result.add("-")
  result.add(intToStr(dt.day, 2))
  result.add("T")
  result.add(intToStr(dt.hour, 2))
  result.add(":")
  result.add(intToStr(dt.minute, 2))
  result.add(":")
  result.add(intToStr(dt.second, 2))
  if dt.microsecond > 0:
    result.add(".")
    result.add(align($dt.microsecond, 6, '0'))
  if dt.utcoffset != 0 or dt.offsetKnown:
    if dt.utcoffset == 0:
      result.add("Z")
    else:
      if dt.utcoffset < 0:
        result.add("-")
      else:
        result.add("+")
      let utcoffset = dt.utcoffset + (if dt.isDST: 3600 else: 0)
      let hr = quotient(abs(utcoffset), 3600)
      let mn = quotient(modulo(abs(utcoffset), 3600), 60)
      result.add(intToStr(hr, 2))
      result.add(":")
      result.add(intToStr(mn, 2))


proc `$`*(td: TimeDelta): string =
  ## a string representation of a Time difference
  ## format: [x days,] h:mm:ss.ffffff
  ##
  result = ""
  if td.days != 0:
    result.add($td.days)
    if abs(td.days) > 1:
      result.add(" days, ")
    else:
      result.add(" day, ")
  var tmp = td.seconds
  let hours = quotient(tmp, 3600)
  tmp -= hours * 3600
  let minutes = quotient(tmp, 60)
  tmp -= minutes * 60
  result.add($hours)
  result.add(":")
  result.add(intToStr(minutes, 2))
  result.add(":")
  result.add(intToStr(tmp,2))

  if td.microseconds > 0:
    result.add(".")
    result.add(align($td.microseconds,6,'0'))


proc `$`*(isod: ISOWeekDate): string =
  ## the string representation of the so called
  ## ISO Week Date format. The four digit year
  ## (which can be different from the actual gregorian
  ## calendar year according to the rules for ISO long years
  ## with 53 weeks), followed by a litteral '-W', the two digit
  ## week number, a '-' and the weekday number according to ISO
  ## (1: Monday, .., 7 Sunday)
  ##
  result = ""
  result.add(intToStr(isod.year, 4))
  result.add("-W")
  result.add(intToStr(isod.week, 2))
  result.add("-")
  result.add($isod.weekday)


proc setUTCOffset*(dt: var DateTime; hours: int = 0, minutes: int = 0) =
  ## set the offset to UTC as hours and minutes east of UTC. Negative
  ## values for locations west of UTC
  ##
  let offset = hours * 3600 + minutes * 60
  dt.utcoffset = offset
  dt.offsetKnown = true


proc setUTCOffset*(dt: var DateTime; seconds: int = 0) =
  ## set the offset to UTC as seconds east of UTC.
  ## negative values for locations west of UTC.
  ##
  dt.utcoffset = seconds
  dt.offsetKnown = true


proc isLeapYear*(year: int): bool =
  ## check if `year` is a leap year.
  ##
  ## algorithm from CommonLisp calendrica-3.0
  ##
  return (modulo(year, 4) == 0) and (modulo(year, 400) notin {100, 200, 300})


proc countLeapYears*(year: int): int =
  ## Returns the number of leap years before `year`.
  ##
  ## **Note:** For leap years, start date is assumed to be 1 AD.
  ## counts the number of leap years up to January 1st of a given year.
  ## Keep in mind that if specified year is a leap year, the leap day
  ## has not happened before January 1st of that year.
  ##
  ## from nims's standard library
  let years = year - 1
  (years div 4) - (years div 100) + (years div 400)


proc toOrdinalFromYMD*(year, month, day: int): int64 =
  ## return the ordinal day number in the proleptic gregorian calendar
  ## 0001-01-01 is day number 1
  ## algorithm from CommonLisp calendrica-3.0
  ##
  result = 0
  result += (365 * (year - 1))
  result += quotient(year - 1, 4)
  result -= quotient(year - 1, 100)
  result += quotient(year - 1, 400)
  result += quotient((367 * month) - 362, 12)
  if month <= 2:
      result += 0
  else:
      if isLeapYear(year):
          result -= 1
      else:
          result -= 2
  result += day


proc toOrdinal*(dt: DateTime): int64 =
  ## return the ordinal number of the date represented
  ## in the `dt` DateTime value.
  ## the same as python's toordinal() and
  ## calendrica-3.0's fixed-from-gregorian
  ##
  return toOrdinalFromYMD(dt.year, dt.month, dt.day)


proc yearFromOrdinal*(ordinal: int64): int =
  ## Return the Gregorian year corresponding to the gregorian ordinal
  ## algorithm from CommonLisp calendrica-3.0
  ##
  let d0   = ordinal - 1
  let n400 = quotient(d0, 146097)
  let d1   = modulo(d0, 146097)
  let n100 = quotient(d1, 36524)
  let d2   = modulo(d1, 36524)
  let n4   = quotient(d2, 1461)
  let d3   = modulo(d2, 1461)
  let n1   = quotient(d3, 365)
  let year = (400 * n400) + (100 * n100) + (4 * n4) + n1
  if n100 == 4 or n1 == 4:
    return year
  else:
    return year + 1


proc fromOrdinal*(ordinal: int64): DateTime =
  ## Return the DateTime Date part corresponding to the gregorian ordinal.
  ## the same as python's fromordinal and calendrica-3.0's
  ## gregorian-from-fixed
  ##
  let year = yearFromOrdinal(ordinal)
  let prior_days = ordinal - toOrdinalFromYMD(year, 1, 1)
  var correction: int
  if (ordinal < toOrdinalFromYMD(year, 3, 1)):
    correction = 0
  else:
    if isLeapYear(year):
      correction = 1
    else:
      correction = 2
  let month = quotient((12 * (prior_days + correction)) + 373, 367)
  let day = int(1 + (ordinal - toOrdinalFromYMD(year, month, 1)))
  result.year = year
  result.month = month
  result.day = day


proc toTimeStamp*(dt: DateTime): TimeStamp =
  ## return number of Seconds and MicroSeconds
  ## since 0001-01-01T00:00:00
  ##
  result.seconds = float64(toOrdinal(dt)) * OneDay
  result.seconds += float64(dt.hour * 60 * 60)
  result.seconds += float64(dt.minute * 60)
  result.seconds += dt.second.float64
  result.microseconds = dt.microsecond.float64


proc toTimeDelta*(dt: DateTime): TimeDelta =
  ## return number of Days, Seconds and MicroSeconds
  ## since 0001-01-01T00:00:00
  ##
  result.days = int(toOrdinal(dt))
  result.seconds = dt.hour * 60 * 60
  result.seconds += dt.minute * 60
  result.seconds += dt.second
  result.microseconds = dt.microsecond


proc kday_on_or_before*(k: int, ordinal_date: int64): int64 =
  ## Return the ordinal date of the k-day on or before ordinal date 'date'.
  ## k=0 means Sunday, k=1 means Monday, and so on.
  ## from CommonLisp calendrica-3.0
  ##
  #return ordinal_date - modulo(ordinal_date - k, 7)
  let od = ordinal_date - (quotient(GregorianEpochSeconds, 86400) - 1)
  return od - modulo(od - k, 7)


proc kday_on_or_after*(k: int, ordinal_date: int64): int64 =
  ## Return the ordinal date of the k-day on or after ordinal date 'date'.
  ## k=0 means Sunday, k=1 means Monday, and so on.
  ## from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 6)


proc kday_nearest*(k: int, ordinal_date: int64): int64 =
  ## Return the ordinal date of the k-day nearest ordinal date 'date'.
  ## k=0 means Sunday, k=1 means Monday, and so on.
  ## ## from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 3)


proc kday_after*(k: int, ordinal_date: int64): int64 =
  ## Return the ordinal date of the k-day after ordinal date 'date'.
  ## k=0 means Sunday, k=1 means Monday, and so on.
  ## from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 7)


proc kday_before*(k: int, ordinal_date: int64): int64 =
  ## Return the ordinal date of the k-day before ordinal date 'date'.
  ## k=0 means Sunday, k=1 means Monday, and so on.
  ## from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date - 1)


proc nth_kday*(nth, k, year, month, day: int): int64 =
  ## Return the fixed date of n-th k-day after Gregorian date 'g_date'.
  ## If n>0, return the n-th k-day on or after  'g_date'.
  ## If n<0, return the n-th k-day on or before 'g_date'.
  ## If n=0, return BOGUS.
  ## A k-day of 0 means Sunday, 1 means Monday, and so on.
  ## from CommonLisp calendrica-3.0
  ##
  let ordinal = int(toOrdinalFromYMD(year, month, day))
  if nth > 0:
    return 7 * nth + kday_before(k, ordinal)
  elif nth < 0:
    return 7 * nth + kday_after(k, ordinal)
  else:
    raise newException(ValueError, "0 is not a valid parameter for nth_kday")


proc toOrdinalFromISO*(isod: ISOWeekDate): int64 =
  ## get the ordinal number of the `isod` ISOWeekDate in
  ## the proleptic gregorian calendar.
  ## same as calendrica-3.0's fixed-from-iso
  ##
  return nth_kday(isod.week, 0, isod.year - 1, 12, 28) + isod.weekday


proc amod*[T](x, y: T): int =
  ## Return the same as modulo(a, b) with b instead of 0.
  return int(y.float64 + modulo(x.float64, -y.float64))


proc toISOWeekDate*(dt: DateTime): ISOWeekDate =
  ## Return the ISO week date (YYYY-Www-wd) corresponding to the DateTime 'dt'.
  ## algorithm from CommonLisp calendrica-3.0's iso-from-fixed
  ##
  let ordinal = toOrdinal(dt)
  let approx = yearFromOrdinal(ordinal)
  var year = approx
  if ordinal >= toOrdinalFromISO(ISOWeekDate(year: approx + 1, week: 1, weekday: 1)):
    year += 1
  let week = 1 + quotient(ordinal -
                          toOrdinalFromISO(ISOWeekDate(year: year, week: 1, weekday: 1)), 7)
  let day = amod(int64(ordinal) - (quotient(GregorianEpochSeconds, 86400) - 1), 7)
  result.year = year
  result.week = week
  result.weekday = day


template `<`*(x, y: TimeStamp): bool =
  x.seconds < y.seconds and
    x.microseconds < y.microseconds


template `==`*(x, y: TimeStamp): bool =
  x.seconds == y.seconds and
    x.microseconds == y.microseconds


template `<`*(x, y: DateTime): bool =
  toTimeStamp(x) < toTimeStamp(y)


template `==`*(x, y: DateTime): bool =
  toTimeStamp(x) == toTimeStamp(y)


template `cmp`*(x, y: DateTime): int =
  let x = toTimeStamp(x)
  let y = toTimeStamp(y)
  if x < y:
    return -1
  elif x > y:
    return 1
  else:
    return 0


proc getDaysInMonth*(month: int, year: int): int =
  ## Get the number of days in a ``month`` of a ``year``
  ## from times module in nim's standard library
  ##
  # http://www.dispersiondesign.com/articles/time/number_of_days_in_a_month
  case month
  of 2: result = if isLeapYear(year): 29 else: 28
  of 4, 6, 9, 11: result = 30
  else: result = 31


proc toTimeStamp*(dt: DateTime, ti: TimeInterval): TimeStamp =
  ## Calculates the number of fractional seconds the interval is worth
  ## relative to `dt`.
  ##
  ## adapted from nim's standard library
  ##
  var anew = dt
  var newinterv = ti

  newinterv.months += ti.years * 12
  var curMonth = anew.month

  result.seconds -= float64(anew.day * OneDay)
  # now we are on day 1 of curMonth

  if newinterv.months < 0:   # subtracting
    for mth in countDown(-1 * newinterv.months.int, 1):
      # subtract the number of seconds in the previous month
      if curMonth == 1:
        curMonth = 12
        anew.year.dec()
      else:
        curMonth.dec()
      result.seconds -= float64(getDaysInMonth(curMonth, anew.year) * 24 * 60 * 60)
  else:  # adding
    # add number of seconds in current month
    for mth in 1 .. newinterv.months.int:
      result.seconds += float64(getDaysInMonth(curMonth, anew.year) * 24 * 60 * 60)
      if curMonth == 12:
        curMonth = 1
        anew.year.inc()
      else:
        curMonth.inc()
  # add the number of seconds we first subtracted back to get to anew.day in the current month
  # we have to make sure that anew.day fits in the current month. if e.g. we startet on monthday 
  # 31 and ended in a month with only 28 days we have to take the smaller of the two values to
  # adjust the number of seconds.
  result.seconds += float64(min(getDaysInMonth(curMonth, anew.year), anew.day) * OneDay)
  
  result.seconds += float64(newinterv.days.int * 24 * 60 * 60)
  result.seconds += float64(newinterv.hours.int * 60 * 60)
  result.seconds += float64(newinterv.minutes.int * 60)
  result.seconds += newinterv.seconds.float64
  result.microseconds += newinterv.microseconds.float64


proc fromTimeStamp*(ts: TimeStamp): DateTime =
  ## return DateTime from TimeStamp (number of seconds since 0001-01-01T00:00:00)
  ## algorithm from CommonLisp calendrica-3.0
  ##
  result = fromOrdinal(quotient(ts.seconds, OneDay))
  var tmp = modulo(ts.seconds, float64(OneDay))
  result.hour = quotient(tmp, 3600)
  tmp = modulo(tmp, 3600.0)
  result.minute = quotient(tmp, 60)
  tmp = modulo(tmp, 60.0)
  result.second = int(tmp)
  result.microsecond = int(ts.microseconds)


proc toTimeInterval*(dt: DateTime): TimeInterval =
  ## convert a DateTime Value into a TimeInterval since
  ## the start of the proleptic Gregorian calendar.
  ## This can be used to calculate what other people
  ## (eg. python's dateutil) call relative time deltas.
  ## The idea for this comes from nim's standard library
  ##
  result.years = dt.year.float64
  result.months = dt.month.float64
  result.days = dt.day.float64
  result.hours = dt.hour.float64
  result.minutes = dt.minute.float64
  result.seconds = dt.second.float64
  result.microseconds = dt.microsecond.float64


proc toUTC*(dt: DateTime): DateTime =
  ## correct the value in `dt` according to the
  ## offset to UTC stored in the value
  ## Offsets have to be subtracted from the stored
  ## value to get the corresponding time in UTC.
  ##
  var s = dt.toTimeStamp()
  s.seconds -= (dt.utcoffset + (if dt.isDST: 3600 else: 0)).float64
  result = fromTimeStamp(s)
  result.offSetKnown = true
  result.utcoffset = 0


proc fromUnixEpochSeconds*(ues: float64, hoffset, moffset: int = 0): DateTime =
  ## the Unix epoch started on 1970-01-01T00:00:00
  ## many programs use this date as the reference
  ## point in their datetime calculations.
  ##
  ## use this to get a DateTime in the proleptic
  ## Gregorian calendar using a value you get eg.
  ## from nim's epochTime(). epochTime() is the
  ## only platform dependent date/time related
  ## procedure used in this module.
  ##
  var seconds = floor(ues) + UnixEpochSeconds.float64
  seconds += float64(hoffset * 3600)
  seconds += float64(moffset * 60)
  let fraction = modulo(ues, 1.0)
  var ts: TimeStamp
  ts.seconds = seconds.float64
  ts.microseconds = fraction * 1e6
  fromTimeStamp(ts)


proc toUnixEpochSeconds*(dt: DateTime): float64 =
  ## get the number of fractional seconds since
  ## start of the Unix epoch on 1970-01-01T00:00:00
  ##
  let ts = toTimeStamp(dt)
  result = float64(ts.seconds - UnixEpochSeconds.float64)
  result += ts.microseconds.float64 / 1e6


proc normalizeTimeStamp(ts: var TimeStamp) =
  ## during various calculations in this module
  ## the value of microseconds will go below zero
  ## or above 1e6. We correct the stored value in
  ## seconds to keep the microseconds between 0
  ## and 1e6 - 1
  ##
  if ts.microseconds < 0:
    ts.seconds -= float64(quotient(ts.microseconds, -1_000_000) + 1)
    ts.microseconds = float64(modulo(ts.microseconds, 1_000_000))
  elif ts.microseconds >= 1_000_000:
    ts.seconds += float64(quotient(ts.microseconds, 1_000_000))
    ts.microseconds = float64(modulo(ts.microseconds, 1_000_000))


proc `-`*(x, y: TimeStamp): TimeStamp =
  ## substract TimeStamp `y` from `x`
  result.seconds = x.seconds - y.seconds
  result.microseconds = x.microseconds - y.microseconds
  normalizeTimeStamp(result)


proc `+`*(x, y: TimeStamp): TimeStamp =
  ## add TimeStamp `y` to `x`
  result.seconds = x.seconds + y.seconds
  result.microseconds = x.microseconds + y.microseconds
  normalizeTimeStamp(result)


proc `-`*(x, y: DateTime): TimeDelta =
  ## subtract DateTime `y` from `x` returning
  ## a TimeDelta which represents the time difference
  ## as a number of days, seconds and microseconds.
  ## As usual in calendrical calculations, this is done
  ## via a roundtrip from DateTime to TimeStamp values
  ## (the fractional number of seconds since the start
  ## of the proleptic Gregorian calendar.)
  ##
  let tdiff = toTimeStamp(x) - toTimeStamp(y)
  result = initTimeDelta(seconds = float64(tdiff.seconds),
                         microseconds = float64(tdiff.microseconds))


template transferOffsetInfo(dt: DateTime) =
  result.offsetKnown = dt.offsetKnown
  result.utcoffset = dt.utcoffset
  result.isDST = dt.isDST

proc `+`*(dt: DateTime, td: TimeDelta): DateTime =
  ## add a TimeDelta `td` (represented as a number of
  ## days, seconds and microseconds) to a DateTime value in `dt`
  ##
  var s: TimeStamp = dt.toTimeStamp()
  let ts = td.toTimeStamp()
  s.seconds += ts.seconds
  s.microseconds += ts.microseconds
  normalizeTimeStamp(s)
  result = fromTimeStamp(s)
  transferOffsetInfo(dt)


template `+`*(dt: DateTime, ts: TimeStamp): DateTime =
  dt + initTimeDelta(seconds = ts.seconds, microseconds = ts.microseconds)


proc `-`*(dt: DateTime, td: TimeDelta): DateTime =
  ## subtract TimeDelta `td` from DateTime value in `dt`
  ##
  result = fromTimeStamp(dt.toTimeStamp() - td.toTimeStamp())
  transferOffsetInfo(dt)  


proc `+`*(dt: DateTime, ti: TimeInterval): DateTime =
  ## adds ``ti`` time to DateTime ``dt``.
  ##
  var ts = toTimeStamp(dt) + toTimeStamp(dt, ti)
  normalizeTimeStamp(ts)
  result = fromTimeStamp(ts)
  transferOffsetInfo(dt)  


proc `-`*(dt: DateTime, ti: TimeInterval): DateTime =
  ## subtracts ``ti`` time from DateTime ``dt``.
  ## this is the same as adding the negated value of `ti`
  ## to `dt`
  ##
  var ts = toTimeStamp(dt) + toTimeStamp(dt, -ti)
  normalizeTimeStamp(ts)
  result = fromTimeStamp(ts)
  transferOffsetInfo(dt)  


template getWeekDay*(dt: DateTime): int =
  ## get the weeday number for the date stored in
  ## `dt`. The day 0001-01-01 was a monday, so we
  ## can take the ordinal number of the date in `dt`
  ## modulo 7 the get the corresponding weekday number.
  ##
  modulo(toOrdinal(dt), 7)


proc getYearDay*(dt: DateTime): int =
  ## get the day number in the year stored in the
  ## date in `dt`. Contrary to a similar function in
  ## nim's standard lib, this procedure gives the ordinal
  ## number of the stored day in the stored year. Not the
  ## number of days before the date stored in `dt`.
  ##
  let ny = DateTime(year: dt.year, month: 1, day: 1)
  return int(toOrdinal(dt) - toOrdinal(ny))


proc easter*(year: int): DateTime =
  ## Return Date of Easter in Gregorian year `year`.
  ## adapted from CommonLisp calendrica-3.0
  ##
  let century = quotient(year, 100) + 1
  let shifted_epact = modulo(14 + (11 * modulo(year, 19)) -
                             quotient(3 * century, 4) +
                             quotient(5 + (8 * century), 25), 30)
  var adjusted_epact = shifted_epact
  if (shifted_epact == 0) or (shifted_epact == 1 and
                                (10 < modulo(year, 19))):
      adjusted_epact = shifted_epact + 1
  else:
      adjusted_epact = shifted_epact
  let paschal_moon = (toOrdinalFromYMD(year, 4, 19)) - adjusted_epact
  return fromOrdinal(kday_after(0, paschal_moon))


proc now*(): DateTime =
  ## get a DateTime instance having the current date
  ## and time from the running system.
  ## This does not set the offset to UTC. It simply
  ## takes what epochTime() gives (a fractional number
  ## of seconds since the start of the Unix epoch) and
  ## converts that number in a DateTime value.
  ##
  result = fromUnixEpochSeconds(epochTime(), hoffset = 2, moffset = 0)
  result.setUTCOffset(2, 0)


proc parseToken(dt: var DateTime; token, value: string; j: var int) =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## Helper of the parse proc to parse individual tokens.
  var sv: int
  case token
  of "d":
    var pd = parseInt(value[j..j+1], sv)
    dt.day = sv
    j += pd
  of "dd":
    dt.day = value[j..j+1].parseInt()
    j += 2
  of "h", "H":
    var pd = parseInt(value[j..j+1], sv)
    dt.hour = sv
    j += pd
  of "hh", "HH":
    dt.hour = value[j..j+1].parseInt()
    j += 2
  of "m":
    var pd = parseInt(value[j..j+1], sv)
    dt.minute = sv
    j += pd
  of "mm":
    dt.minute = value[j..j+1].parseInt()
    j += 2
  of "M":
    var pd = parseInt(value[j..j+1], sv)
    dt.month = sv
    j += pd
  of "MM":
    var month = value[j..j+1].parseInt()
    j += 2
    dt.month = month
  of "MMM":
    case value[j..j+2].toLowerAscii():
    of "jan": dt.month =  1
    of "feb": dt.month =  2
    of "mar": dt.month =  3
    of "apr": dt.month =  4
    of "may": dt.month =  5
    of "jun": dt.month =  6
    of "jul": dt.month =  7
    of "aug": dt.month =  8
    of "sep": dt.month =  9
    of "oct": dt.month =  10
    of "nov": dt.month =  11
    of "dec": dt.month =  12
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMM), got: " & value)
    j += 3
  of "MMMM":
    if value.len >= j+7 and value[j..j+6].cmpIgnoreCase("january") == 0:
      dt.month =  1
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("february") == 0:
      dt.month =  2
      j += 8
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("march") == 0:
      dt.month =  3
      j += 5
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("april") == 0:
      dt.month =  4
      j += 5
    elif value.len >= j+3 and value[j..j+2].cmpIgnoreCase("may") == 0:
      dt.month =  5
      j += 3
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("june") == 0:
      dt.month =  6
      j += 4
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("july") == 0:
      dt.month =  7
      j += 4
    elif value.len >= j+6 and value[j..j+5].cmpIgnoreCase("august") == 0:
      dt.month =  8
      j += 6
    elif value.len >= j+9 and value[j..j+8].cmpIgnoreCase("september") == 0:
      dt.month =  9
      j += 9
    elif value.len >= j+7 and value[j..j+6].cmpIgnoreCase("october") == 0:
      dt.month =  10
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("november") == 0:
      dt.month =  11
      j += 8
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("december") == 0:
      dt.month =  12
      j += 8
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMMM), got: " & value)
  of "s":
    var pd = parseInt(value[j..j+1], sv)
    dt.second = sv
    j += pd
  of "ss":
    dt.second = value[j..j+1].parseInt()
    j += 2
  of "t":
    if value[j] == 'P' and dt.hour > 0 and dt.hour < 12:
      dt.hour += 12
    j += 1
  of "tt":
    if value[j..j+1] == "PM" and dt.hour > 0 and dt.hour < 12:
      dt.hour += 12
    j += 2
  of "yyyy":
    dt.year = value[j..j+3].parseInt()
    j += 4
  of "z":
    dt.offsetKnown = true
    if value[j] == '+':
      dt.utcoffset = parseInt($value[j+1]) * 3600
    elif value[j] == '-':
      dt.utcoffset = 0 - parseInt($value[j+1]) * -3600
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (z), got: " & value[j])
    j += 2
  of "zz":
    dt.offsetKnown = true
    if value[j] == '+':
      dt.utcoffset = value[j+1..j+2].parseInt() * 3600
    elif value[j] == '-':
      dt.utcoffset = 0 - value[j+1..j+2].parseInt() * 3600
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zz), got: " & value[j])
    j += 3
  of "zzz":
    var factor = 0
    if value[j] == '+': factor = 1
    elif value[j] == '-': factor = -1
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zzz), got: " & value[j])
    dt.utcoffset = factor * value[j+1..j+2].parseInt() * 3600
    j += 4
    dt.utcoffset += factor * value[j..j+1].parseInt() * 60
    dt.offsetKnown = true
    j += 2
  else:
    # Ignore the token and move forward in the value string by the same length
    j += token.len


proc parse*(value, layout: string): DateTime =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## This function parses a date/time string using the standard format
  ## identifiers as listed below.
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    yyyy     four digit year.                                                                   ``2012 -> 2012``
  ##    z        Displays the timezone offset from UTC. ``Z`` is parsed as ``+0``                   ``GMT+7 -> +7``, ``GMT-5 -> -5``
  ##    zz       Same as above but with leading 0.                                                  ``GMT+7 -> +07``, ``GMT-5 -> -05``
  ##    zzz      Same as above but with ``:mm`` where *mm* represents minutes.                      ``GMT+7 -> +07:00``, ``GMT-5 -> -05:00``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.
  var i = 0 # pointer for format string
  var j = 0 # pointer for value string
  var token = ""
  # Assumes current day of month, month and year, but time is reset to 00:00:00.
  var dt = now()
  dt.hour = 0
  dt.minute = 0
  dt.second = 0
  dt.microsecond = 0

  while true:
    case layout[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      if token.len > 0:
        parseToken(dt, token, value, j)
      # Reset token
      token = ""
      # Break if at end of line
      if layout[i] == '\0': break
      # Skip separator and everything between single quotes
      # These are literals in both the layout and the value string
      if layout[i] == '\'':
        inc(i)
        while layout[i] != '\'' and layout.len-1 > i:
          inc(i)
          inc(j)
        inc(i)
      else:
        inc(i)
        inc(j)
    else:
      # Check if the letter being added matches previous accumulated buffer.
      if token.len < 1 or token[high(token)] == layout[i]:
        token.add(layout[i])
        inc(i)
      else:
        parseToken(dt, token, value, j)
        token = ""

  return dt


const WeekDayNames: array[7, string] = ["Sunday", "Monday", "Tuesday", "Wednesday",
     "Thursday", "Friday", "Saturday"]

const MonthNames: array[1..12, string] = ["January", "February", "March",
      "April", "May", "June", "July", "August", "September", "October",
      "November", "December"]


proc formatToken(dt: DateTime, token: string, buf: var string) =
  ## Helper of the format proc to parse individual tokens.
  ##
  ## Pass the found token in the user input string, and the buffer where the
  ## final string is being built. This has to be a var value because certain
  ## formatting tokens require modifying the previous characters.
  case token
  of "d":
    buf.add($dt.day)
  of "dd":
    if dt.day < 10:
      buf.add("0")
    buf.add($dt.day)
  of "ddd":
    buf.add($WeekDayNames[getWeekDay(dt)][0 .. 2])
  of "dddd":
    buf.add($WeekDayNames[getWeekDay(dt)])
  of "h":
    buf.add($(if dt.hour > 12: dt.hour - 12 else: dt.hour))
  of "hh":
    let amerHour = if dt.hour > 12: dt.hour - 12 else: dt.hour
    if amerHour < 10:
      buf.add('0')
    buf.add($amerHour)
  of "H":
    buf.add($dt.hour)
  of "HH":
    if dt.hour < 10:
      buf.add('0')
    buf.add($dt.hour)
  of "m":
    buf.add($dt.minute)
  of "mm":
    if dt.minute < 10:
      buf.add('0')
    buf.add($dt.minute)
  of "M":
    buf.add($dt.month)
  of "MM":
    if dt.month < 10:
      buf.add('0')
    buf.add($dt.month)
  of "MMM":
    buf.add($MonthNames[dt.month][0..2])
  of "MMMM":
    buf.add($MonthNames[dt.month])
  of "s":
    buf.add($dt.second)
  of "ss":
    if dt.second < 10:
      buf.add('0')
    buf.add($dt.second)
  of "t":
    if dt.hour >= 12:
      buf.add('P')
    else: buf.add('A')
  of "tt":
    if dt.hour >= 12:
      buf.add("PM")
    else: buf.add("AM")
  of "y", "yy", "yyy", "yyyy":
    buf.add(intToStr(dt.year, 4))
  of "yyyyy":
    buf.add(intToStr(dt.year, 5))
  of "z":
    let
      nonDstTz = dt.utcoffset - int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    buf.add($hours)
  of "zz":
    let
      nonDstTz = dt.utcoffset - int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
  of "zzz":
    let
      nonDstTz = dt.utcoffset + int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
      minutes = (abs(nonDstTz) div 60) mod 60
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
    buf.add(':')
    if minutes < 10: buf.add('0')
    buf.add($minutes)
  of "":
    discard
  else:
    raise newException(ValueError, "Invalid format string: " & token)


proc format*(dt: DateTime, f: string): string =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## This function formats `dt` as specified by `f`. The following format
  ## specifiers are available:
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    ddd      Three letter string which indicates the day of the week.                           ``Saturday -> Sat``, ``Monday -> Mon``
  ##    dddd     Full string for the day of the week.                                               ``Saturday -> Saturday``, ``Monday -> Monday``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    y(yyyy)  This displays the 4-digit year                                                     ``padded with leading zero's if necessary``
  ##    z(zz)    Displays the timezone offset from UTC.                                             ``0 -> Z (if known), others -> +hh:mm or -hh:mm``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.

  result = ""
  var i = 0
  var currentF = ""
  while true:
    case f[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      formatToken(dt, currentF, result)

      currentF = ""
      if f[i] == '\0': break

      if f[i] == '\'':
        inc(i) # Skip '
        while f[i] != '\'' and f.len-1 > i:
          result.add(f[i])
          inc(i)
      else: result.add(f[i])

    else:
      # Check if the letter being added matches previous accumulated buffer.
      if currentF.len < 1 or currentF[high(currentF)] == f[i]:
        currentF.add(f[i])
      else:
        formatToken(dt, currentF, result)
        dec(i) # Move position back to re-process the character separately.
        currentF = ""

    inc(i)


proc strftime*(dt: DateTime, fmtstr: string): string =
  ## a limited reimplementation of strftime, mainly based
  ## on the version implemented in lua, with some influences
  ## from the python version and some convenience features,
  ## such as a shortcut to get a DateTime formatted according
  ## to the rules in RFC3339
  ##
  result = ""
  let fmtLength = len(fmtstr)
  var i = 0
  while i < fmtLength:
    if fmtstr[i] == '%':
      if i + 1 == fmtLength:
        result.add(fmtstr[i])
        break
      inc(i)
      case fmtstr[i]
      of '%':
        result.add("%")
      of 'a':
        result.add(WeekDayNames[getWeekDay(dt)][0..2])
      of 'A':
        result.add(WeekDayNames[getWeekDay(dt)])
      of 'b':
        result.add(MonthNames[dt.month][0..2])
      of 'B':
        result.add(MonthNames[dt.month])
      of 'C':
        result.add($(dt.year div 100))
      of 'd':
        result.add(intToStr(dt.day, 2))
      of 'f':
        result.add(align($dt.microsecond, 6, '0'))
      of 'F':
        result.add(intToStr(dt.year, 4))
        result.add("-")
        result.add(intToStr(dt.month, 2))
        result.add("-")
        result.add(intToStr(dt.day, 2))
      of 'g':
        let iso = toISOWeekDate(dt)
        result.add($(iso.year div 100))
      of 'G':
        let iso = toISOWeekDate(dt)
        result.add($iso.year)
      of 'H':
        result.add(intToStr(dt.hour, 2))
      of 'I':
        var hour: int
        if dt.hour == 0:
          hour = 12
        elif dt.hour > 12:
          hour = dt.hour - 12
        result.add(intToStr(dt.hour, 2))
      of 'j':
        let daynr = getYearDay(dt)
        result.add(intToStr(daynr, 3))
      of 'm':
        result.add(intToStr(dt.month, 2))
      of 'M':
        result.add(intToStr(dt.minute, 2))
      of 'p':
        if dt.hour < 12:
          result.add("AM")
        else:
          result.add("PM")
      of 'S':
        result.add(intToStr(dt.second, 2))
      of 'T':
        result.add(intToStr(dt.hour, 2))
        result.add(":")
        result.add(intToStr(dt.minute, 2))
        result.add(":")
        result.add(intToStr(dt.second, 2))
      of 'u':
        let iso = toISOWeekDate(dt)
        result.add($iso.weekday)
      of 'U':
        let first_sunday = kday_on_or_after(0, int64(toOrdinalFromYMD(dt.year, 1, 1)))
        let fixed = toOrdinal(dt).int64
        if fixed < first_sunday:
          result.add("00")
        else:
          result.add(intToStr(((fixed.int64 - first_sunday) div 7 + 1).int, 2))
      of 'V':
        let iso = toISOWeekDate(dt)
        result.add($iso.week)
      of 'w':
        result.add($getWeekDay(dt))
      of 'W':
        let first_monday = kday_on_or_after(1, toOrdinalFromYMD(dt.year, 1, 1).int64)
        let fixed = toOrdinal(dt).int64
        if fixed < first_monday:
          result.add("00")
        else:
          result.add(intToStr(((fixed - first_monday) div 7 + 1).int, 2))
      of 'y':
        result.add(intToStr(dt.year mod 100, 2))
      of 'Y':
        result.add(intToStr(dt.year, 4))
      of 'z':
        if dt.offsetKnown:
          let utcoffset = dt.utcoffset + int(dt.isDST) * 3600
          if utcoffset == 0:
            result.add("Z")
          else:
            if utcoffset < 0:
              result.add("-")
            else:
              result.add("+")
            result.add(intToStr(abs(utcoffset) div 3600, 2))
            result.add(":")
            result.add(intToStr((abs(utcoffset) mod 3600) div 60, 2))
      else:
        discard

    elif fmtstr[i] == '$':
      inc(i)
      if len(fmtstr[i..^1]) >= 3 and fmtstr[i..i+2] == "iso":
        result.add(dt.strftime("%Y-%m-%dT%H:%M:%S"))
        inc(i, 2)
      elif len(fmtstr[i..^1]) >= 4 and fmtstr[i..i+3] == "wiso":
        result.add(dt.strftime("%G-W%V-%u"))
        inc(i, 3)
      elif len(fmtstr[i..^1]) >= 4 and fmtstr[i..i+3] == "http":
        result.add(dt.strftime("%a, %d %b %Y %T GMT"))
        inc(i, 3)
      elif len(fmtstr[i..^1]) >=  5 and fmtstr[i..i+4] == "ctime":
        result.add(dt.strftime("%a %b %d %T GMT %Y"))
        inc(i, 4)
      elif len(fmtstr[i..^1]) >= 6 and fmtstr[i..i+5] == "rfc850":
        result.add(dt.strftime("%A, %d-%b-%y %T GMT"))
        inc(i, 5)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "rfc1123":
        result.add(dt.strftime("%a, %d %b %Y %T GMT"))
        inc(i, 6)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "rfc3339":
        result.add(dt.strftime("%Y-%m-%dT%H:%M:%S"))
        if dt.microsecond > 0:
          result.add(".")
          result.add(align($dt.microsecond, 6, '0'))
        if dt.offsetKnown:
          let utcoffset = dt.utcoffset + int(dt.isDST) * 3600
          if utcoffset == 0:
            result.add("Z")
          else:
            if utcoffset < 0:
              result.add("-")
            else:
              result.add("+")
            let offset = abs(utcoffset)
            let hr = offset div 3600
            let mn = (offset mod 3600) div 60
            result.add(intToStr(hr, 2))
            result.add(":")
            result.add(intToStr(mn, 2))
        inc(i, 6)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "asctime":
        result.add(dt.strftime("%a %b %d %T %Y"))
        inc(i, 6)
    else:
      result.add(fmtstr[i])
    inc(i)


proc fromRFC3339*(self: string): DateTime =
  ## taken from skrylar's rfc3339 module on github. with some
  ## corrections according to my own understanding of RFC3339
  ##
  ## Parses a string as an RFC3339 date, returning an DateTime object.
  var i = 0

  template getch(): char =
    inc i
    if i > self.len:
      break
    self[i-1]

  template getdigit(): char =
    let xx = getch
    if xx < '0' or xx > '9':
      break
    xx

  var scratch = newString(4)
  var work = DateTime()

  block date:
    var x: int
    # load year
    scratch[0] = getdigit
    scratch[1] = getdigit
    scratch[2] = getdigit
    scratch[3] = getdigit
    discard parseint(scratch, x)
    work.year = x

    if getch != '-': break

    # load month
    setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.month = x

    if getch != '-': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.day = x

    if getch != 'T': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.hour = x

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.minute = x

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.second = x

    var ch = getch
    if ch == '.':
      var factor: float64 = 10.0
      var fraction: float64 = 0.0
      while true:
        setLen(scratch, 1)
        scratch[0] = getdigit
        discard parseint(scratch, x)
        fraction += float64(x) / factor
        factor *= 10
      work.microsecond = int(fraction * 1e6)
      dec(i)
      ch = getch
    case ch
      of 'z', 'Z':
        work.offsetKnown = true
        work.utcoffset = 0
      of '-', '+':
        work.offsetKnown = true
        setLen(scratch, 2)
        scratch[0] = getdigit
        scratch[1] = getdigit
        discard parseint(scratch, x)
        work.utcoffset = x * 3600

        if getch != ':': break

        scratch[0] = getdigit
        scratch[1] = getdigit
        discard parseint(scratch, x)
        work.utcoffset += x * 60

        if ch == '-':
          work.utcoffset *= -1
      else:
        discard
  return work

when isMainModule:
  ## some experiments...
  ##

  echo "what's the datetime of the first day in backwards"
  echo "extrapolated (proleptic) gregorian calendar?"
  
  var dt = fromOrdinal(1)
  echo $dt
  echo $dt.toTimeStamp()

  echo ""
  echo "can we store fractional seconds?"
  dt = fromTimeStamp(TimeStamp(seconds: 86401, microseconds: 1234567890))
  echo $dt
  echo $dt.toTimeStamp()

  echo ""
  echo "store the current UTC date/time given by the running system"
  var current = fromUnixEpochSeconds(epochTime(), hoffset=0, moffset=0)
  
  echo "now: ", current, " weekday: ", getWeekDay(current), " yearday: ", getYearDay(current)

  echo ""
  echo "the date/time value of the start of the UnixEpoch"
  var epd = fromTimeStamp(TimeStamp(seconds: float(UnixEpochSeconds)))
  echo "epd: ", epd
  echo ""
  
  var td = current - epd
  echo "time delta since Unix epoch: ", td
  echo "total seconds since Unix epoch: ", td.totalSeconds()
  echo "epd + ts ", fromTimeStamp(epd.toTimeStamp() + initTimeStamp(seconds = td.totalSeconds()))
  echo "epd + td ", epd + td
  assert epd + td == current
  echo "now - td ", current - td
  assert current - td == epd

  echo ""
  echo epd.toTimeStamp()
  echo initTimeStamp(seconds = td.totalSeconds)
  echo epd.toTimeStamp() + initTimeStamp(seconds = td.totalSeconds())

  echo ""
  var ti = current.toTimeInterval() - epd.toTimeInterval()
  echo "TimeInterval since Unix epoch:"
  echo $ti
  echo "epd + ti: ", epd + ti, " == ", current
  echo "now - ti: ", current - ti, " == ", epd
  echo ""
  echo "TimeInterval back to Unix epoch:"
  ti = epd.toTimeInterval() - current.toTimeInterval()
  echo $ti
  echo "now + ti: ", current + ti, " == ", epd
  assert current + ti == epd
  echo "epd - ti: ", epd - ti, " == ", current
  assert(epd - ti == current)

  echo ""
  echo "can we initialize a TimeDelta value from a known number of seconds"
  td = initTimeDelta(seconds=td.totalSeconds)
  echo td
  assert epd + td == current

  # experiments with fractional values used to initialize
  # a TimeDelta and playing with relative date/time differences
  # inspired by nim's standard library.
  td = initTimeDelta(microseconds=1.5e6, days=0.5, minutes=0.5)
  echo(7.months + 5.months + 1.days + 35.days + 72.hours + 75.25e6.int.microseconds)
  echo current + 1.years - (12.months + 5.months)
  echo current + 1.years - 12.months + 5.months

  echo ""
  echo  "some notable dates in the Unix epoch ..."

  var a = fromUnixEpochSeconds(1_000_000_000)
  var b = fromUnixEpochSeconds(1_111_111_111)
  var c = fromUnixEpochSeconds(1_234_567_890)
  var d = fromUnixEpochSeconds(1_500_000_000)
  var e = fromUnixEpochSeconds(2_000_000_000)
  var f = fromUnixEpochSeconds(2_500_000_000.0)
  var g = fromUnixEpochSeconds(3_000_000_000.0)
  echo ""
  echo "one billion seconds since epoch:   ", $a, " time delta: ", $(a - epd)
  assert int((a - epd).totalSeconds()) == 1_000_000_000
  echo "1_111_111_111 seconds since epoch: ", $b, " time delta: ", $(b - epd)
  assert int((b - epd).totalSeconds()) == 1_111_111_111
  echo "1.5 billion seconds since epoch:   ", $c, " time delta: ", $(c - epd)
  assert int((c -  epd).totalSeconds()) == 1_234_567_890
  echo "1_234_567_890 seconds since epoch: ", $d, " time delta: ", $(d - epd)
  assert int((d - epd).totalSeconds()) == 1_500_000_000
  echo "2   billion seconds since epoch:   ",   $e, " time delta: ", $(e - epd)
  assert int((e - epd).totalSeconds()) == 2_000_000_000
  echo "2.5 billion seconds since epoch:   ",   $f, " time delta: ", $(f - epd)
  assert int((f - epd).totalSeconds()) == 2_500_000_000
  echo "3   billion seconds since epoch:   ", $e, " time delta: ", $(e - epd)
  assert int((g - epd).totalSeconds()) == 3_000_000_000

  echo "check dates from wikipedia page about Unix Time"
  assert $a == "2001-09-09T01:46:40"
  assert $b == "2005-03-18T01:58:31"
  assert $c == "2009-02-13T23:31:30"
  assert $d == "2017-07-14T02:40:00"
  assert $e == "2033-05-18T03:33:20"
  
  echo ""
  echo "the end of the Unix signed 32bit time:"
  e = fromUnixEpochSeconds(pow(2.0, 31))
  assert $e == "2038-01-19T03:14:08"
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval()))[1..^2], " from now"
  echo "the smallest representable time in signed 32bit Unix time:"
  e = fromUnixEpochSeconds(-pow(2.0, 31))
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval()))[1..^2], " from now"
  assert $e == "1901-12-13T20:45:52"
  echo ""
  echo "the end of the Unix unsigned 32bit time:"
  e = fromUnixEpochSeconds(pow(2.0, 32) - 1)
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval()))[1..^2], " from now"
  assert $e == "2106-02-07T06:28:15"
  when not defined(js):
    echo "the end of the Unix signed 64bit time:"
    echo "first calculate the maximal date from a signed 64bit number of seconds since 0001-01-01:"
    var maxordinal = quotient(high(int64), 86400)
    var maxdate = fromOrdinal(maxordinal)
    echo "maxdate: ", maxdate
    echo "now we add the Unix epoch start date as a TimeDelta"
    maxdate = maxdate + toTimeDelta(epd)
    echo maxdate
    var time_in_maxdate = high(int64) - maxordinal * 86400
    echo "the remaining seconds give the time of day on maxdate: ", time_in_maxdate
    maxdate.hour = int(time_in_max_date div 3600)
    maxdate.minute = int((time_in_max_date - 3600 * maxdate.hour) div 60)
    maxdate.second = int(time_in_max_date mod 60)
    echo "now we have the end of the signed 64bit Unix epoch time:"
    echo maxdate, " is it a leap year? ", if isLeapYear(maxdate.year): "yes" else: "no"
    var lycount = countLeapYears(maxdate.year)
    echo "leap years before the end of 64bit time: ", lycount
    
    assert $maxdate == "292277026596-12-04T15:30:07"

  # playing with the surprisingly powerful idea to
  # convert DateTime values into time differences
  # relative to the start of the gregorian calendar.
  # we get a working base to calculate relative
  # time differences.
  echo "time intervals:"
  ti = b.toTimeInterval() - a.toTimeInterval()
  var ti2 = c.toTimeInterval() - a.toTimeInterval()
  echo "time interval ti between ", a, " and ", b
  echo ti
  echo "a + ti:  ", a + ti, " == ", b
  assert $(a + ti) == $b
  echo "b - ti:  ", b - ti, " == ", a
  assert $(b - ti) == $a
  echo "---"
  echo "time interval ti2 between ", a, " and ", c
  echo ti2
  echo "a + ti2: ", a + ti2, " == ", c
  assert $(a + ti2) == $c
  echo "c - ti2: ", c - ti2, " == ", a
  assert $(c - ti2) == $a

  echo "---"

  # usually there is the problem that you get different
  # results in relative time difference calculations,
  # depending on whether you first add/subtract the values
  # from big to small or from small to big.

  # relative time differences using months is a highly
  # problematic matter which i am only marginally interested
  # in. usually you don't get to the same point if you add
  # a number of months and then subtract the same number
  # again. An example: typically if you add 1 month to january 31
  # the algorithms in use are clever enough to land on february 28 or 29
  # but when you go back one month... let's see:
  echo "experimenting with time intervals:"
  var j = parse("2020-01-31 01:02:03", "yyyy-MM-dd hh:mm:ss")
  echo "start: ", j
  echo "plus one month:"
  echo toTimeStamp(j, 1.months)
  let j1 = j + 1.months
  echo j1
  echo "and back:"
  j = j1 - 1.months
  echo j
  echo "we are no longer on the same date, but it is not clear, what could be done to fix that."
  echo "the logic used here is:"
  echo "given the reference datetime dt"
  echo "first subtract the day in month from dt to get to the first day of the month in dt"
  echo "then add/subtract the number of months from dt (actually the number of seconds the"
  echo "month difference is worth relative to dt)."
  echo "add the day in month from dt back to the result."
  echo "if the day does not exist in the target month, correct the day to the last day in the target month."
  echo ""
  echo "subtracting years: ", ti.years, " from: ", b
  var tmp = b - years(ti.years.int)
  echo tmp
  echo "subtracting months: ", ti.months
  tmp = tmp - months(ti.months.int)
  echo tmp
  echo "subtracting days: ", ti.days
  tmp = tmp - days(ti.days.int)
  echo tmp

  echo ""
  echo "negative time interval ti between earlier and later: ", $a, " and ", $b
  echo "---"
  ti = a.toTimeInterval() - b.toTimeInterval()
  echo $ti
  echo "a - ti:  ", a - ti, " == ", b
  echo "b + ti:  ", b + ti, " == ", a
  echo "---"
  echo "negative time interval ti2 between earlier: ", a, " and later ", c
  ti2 = a.toTimeInterval() - c.toTimeInterval()
  echo $ti2
  echo "a - ti2: ", a - ti2, " == ", c
  echo "c + ti2: ", c + ti2, " == ", a

  #
  # some silliness ...
  echo ""
  echo "back 100_000 years"
  var z = current - 100_000.years
  echo z
  echo "and forward again"
  echo  z + 100_000.years
  echo ""
  echo "one million years and 1001 days forward"
  z = current + 1_000_000.years + initTimeDelta(days = 1001)
  echo z, ", ", z.getWeekDay(), " ", z.getYearDay()
  echo "and back again in two steps"
  z = z - 1_000_000.years
  echo z
  echo z - initTimeDelta(days = 1001)

  #
  echo ""
  echo "easter date next 10 years:"
  for i in 1..10:
    echo easter((current + i.years).year).strftime("$iso, $asctime, $wiso")
