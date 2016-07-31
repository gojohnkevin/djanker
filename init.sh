#!/bin/bash
# This script initializes the Django project. It will be executed (from 
# supervisord) every time the Docker image is run.

# If we're not in production, create a temporary dev database
if [ "$DJANGO_PRODUCTION" == "false" ]; then
    echo "DJANGO_PRODUCTION=false; creating local database..."
    # Wait until the MySQL daemon is running
    while [ "$(pgrep mysql | wc -l)" -eq 0 ] ; do
        echo "MySQL daemon not running; waiting one second..."
        sleep 1
    done
    # Wait until we can successfully connect to the MySQL daemon
    until mysql -uroot -pdevrootpass -e ";" ; do
        echo "Can't connect to MySQL; waiting one second..."
        sleep 1
    done
    echo "MySQL daemon is running; creating database..."
    mysql -uroot -e "CREATE DATABASE ${MYSQL_DB}; CREATE USER ${MYSQL_USER}@localhost; SET PASSWORD FOR ${MYSQL_USER}@localhost=PASSWORD('${MYSQL_PASSWORD}'); GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASSWORD}'; FLUSH PRIVILEGES;" -pdevrootpass;
else
    echo "DJANGO_PRODUCTION=true; no local database created"        
fi

# Initialize Django project
python /opt/djanker-project/djanker/manage.py collectstatic --noinput
python /opt/djanker-project/djanker/manage.py migrate --noinput

# Create a Django superuser named `root` if it doesn't yet exist
echo "Creating Django superuser named 'root'..."
if [ "$DJANGO_PRODUCTION" != "true" ]; then
    # We're in the dev environment
    if [ "$DJANGO_SUPERUSER_PASSWORD" == "" ]; then
        # Root password environment variable is not set; so, load it from config.ini
        echo "from ConfigParser import SafeConfigParser; parser = SafeConfigParser(); parser.read('/opt/djanker-project/config'); from django.contrib.auth.models import User; print 'Root user already exists' if User.objects.filter(username=os.environ['DJANGO_SUPERUSER_USERNAME']) else User.objects.create_superuser(os.environ['DJANGO_SUPERUSER_USERNAME'], os.environ['DJANGO_SUPERUSER_EMAIL'], parser.get('general', 'DJANGO_SUPERUSER_PASSWORD'))" | python /opt/djanker-project/djanker/manage.py shell
    else
        # Root password environment variable IS set; so, use it
        echo "import os; from django.contrib.auth.models import User; print 'Root user already exists' if User.objects.filter(username='root') else User.objects.create_superuser(os.environ['DJANGO_SUPERUSER_USERNAME'], os.environ['DJANGO_SUPERUSER_EMAIL'], os.environ['DJANGO_SUPERUSER_PASSWORD'])" | python /opt/djanker-project/djanker/manage.py shell
    fi
else
    # We're in production; use root password environment variable
    echo "import os; from django.contrib.auth.models import User; print 'Root user already exists' if User.objects.filter(username='root') else User.objects.create_superuser(os.environ['DJANGO_SUPERUSER_USERNAME'], os.environ['DJANGO_SUPERUSER_EMAIL'], os.environ['DJANGO_SUPERUSER_PASSWORD'])" | python /opt/djanker-project/djanker/manage.py shell
fi
