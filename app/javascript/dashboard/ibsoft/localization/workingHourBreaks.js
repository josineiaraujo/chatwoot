import parse from 'date-fns/parse';
import getHours from 'date-fns/getHours';
import getMinutes from 'date-fns/getMinutes';
import differenceInMinutes from 'date-fns/differenceInMinutes';

const getTime = (hour, minute) => {
  const meridian = hour > 11 ? 'PM' : 'AM';
  const modHour = hour > 12 ? hour % 12 : hour || 12;
  const parsedHour = modHour < 10 ? `0${modHour}` : modHour;
  const parsedMinute = minute < 10 ? `0${minute}` : minute;
  return `${parsedHour}:${parsedMinute} ${meridian}`;
};

const getValue = (item, snakeKey, camelKey) => item[snakeKey] ?? item[camelKey];

export const defaultWorkingHourBreak = {
  from: '12:00 PM',
  to: '01:00 PM',
  valid: true,
};

export const isValidWorkingHourBreak = ({ from, to }) => {
  if (!from || !to) return false;

  return (
    differenceInMinutes(
      parse(to, 'hh:mm a', new Date()),
      parse(from, 'hh:mm a', new Date())
    ) > 0
  );
};

export const parseWorkingHourBreaks = breaks =>
  Array(breaks)
    .flat()
    .filter(Boolean)
    .reduce((acc, item) => {
      const day = getValue(item, 'day_of_week', 'dayOfWeek');
      const slot = {
        from: getTime(
          getValue(item, 'start_hour', 'startHour'),
          getValue(item, 'start_minutes', 'startMinutes')
        ),
        to: getTime(
          getValue(item, 'end_hour', 'endHour'),
          getValue(item, 'end_minutes', 'endMinutes')
        ),
        valid: true,
      };

      acc[day] = [...(acc[day] || []), slot];
      return acc;
    }, {});

export const transformWorkingHourBreaks = breaksByDay =>
  Object.entries(breaksByDay || {}).flatMap(([day, breaks]) =>
    Array(breaks)
      .flat()
      .filter(isValidWorkingHourBreak)
      .map(item => {
        const fromDate = parse(item.from, 'hh:mm a', new Date());
        const toDate = parse(item.to, 'hh:mm a', new Date());

        return {
          day_of_week: Number(day),
          start_hour: getHours(fromDate),
          start_minutes: getMinutes(fromDate),
          end_hour: getHours(toDate),
          end_minutes: getMinutes(toDate),
        };
      })
  );
