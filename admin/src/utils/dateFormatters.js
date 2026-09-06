const dateFormatter = new Intl.DateTimeFormat(undefined, {
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
});

const dateTimeFormatter = new Intl.DateTimeFormat(undefined, {
  dateStyle: 'short',
  timeStyle: 'short',
});

export function formatDate(value) {
  return value ? dateFormatter.format(new Date(value)) : '-';
}

export function formatDateTime(value) {
  return value ? dateTimeFormatter.format(new Date(value)) : '-';
}
