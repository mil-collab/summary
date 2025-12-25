#!/bin/sh
# cleanup.sh
# Usage: ./cleanup.sh /path/to/folder duration
# Example: ./cleanup.sh /tmp 1h

DIR="$1"
DURATION="$2"

if [ -z "$DIR" ] || [ -z "$DURATION" ]; then
  echo "Usage: $0 /path/to/folder duration"
  echo "Duration format: <number>[m|h|d]  (e.g., 30m, 1h, 2d)"
  exit 1
fi

# Extract numeric value (digits only)
VALUE=`echo "$DURATION" | sed 's/[^0-9].*$//'`

# Extract unit (last character)
UNIT=`echo "$DURATION" | sed 's/^[0-9]\+//'`

# Convert to minutes
case "$UNIT" in
  m) MINUTES="$VALUE" ;;
  h) MINUTES=`expr "$VALUE" \* 60` ;;
  d) MINUTES=`expr "$VALUE" \* 1440` ;; # 24*60
  *) echo "Invalid duration unit. Use m, h, or d."; exit 1 ;;
esac

# Run the deletion
find "$DIR" -type f -mmin +"$MINUTES" | while read FILE; do
  echo "Deleting $FILE"
  rm -f "$FILE"
done

echo "Done"

