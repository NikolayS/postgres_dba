#!/bin/bash
# Add this to crontab to refresh timezone names daily
# Example cron job line:
# 0 0 * * * psql -U postgres -d postgres -c "\i /path/to/postgres_dba/matviews/refresh_timezone_names.sql" > /dev/null 2>&1

echo "To install the timezone refresh cron job, add this to your crontab:"
echo "0 0 * * * psql -U [your_username] -d [your_database] -c \"\i $(pwd)/../matviews/refresh_timezone_names.sql\" > /dev/null 2>&1"
echo
echo "Run 'crontab -e' to edit your crontab and add the line above."