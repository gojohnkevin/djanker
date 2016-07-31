FROM ubuntu:14.04

MAINTAINER kevin@thekevingo.com

# Enable production settings by default; for development, this can be set to 
# `true` in `docker run --env`
ENV DJANGO_PRODUCTION=false

# Set terminal to be noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Install packages
RUN apt-get update && apt-get install -y \
    git \
    libmysqlclient-dev \
    mysql-server \
    nginx \
    python-dev \
    python-mysqldb \
    python-setuptools \
    python-urllib3 \
    python-virtualenv \
    supervisor \
    vim
RUN easy_install pip

# Handle urllib3 InsecurePlatformWarning
RUN apt-get install -y libffi-dev libssl-dev libpython2.7-dev
RUN pip install requests[security] ndg-httpsclient pyasn1 uwsgi


# Configure Django project
RUN mkdir -p /opt/djanker-project/requirements /user-data 

# Configure Django project
#ADD . /code
#RUN mkdir /djangomedia
#RUN mkdir /static
#RUN mkdir /logs
#RUN mkdir /logs/nginx
#RUN mkdir /logs/gunicorn
#WORKDIR /code
#RUN pip install -r requirements.txt
#RUN chmod ug+x /code/initialize.sh

# Expose ports
# 80 = Nginx
# 8000 = Gunicorn
# 3306 = MySQL
EXPOSE 80 8000 3306

# Default folder is djanker app
WORKDIR /opt/djanker-project

# This init.sh entrypoint will ensure the environment is setup
ENTRYPOINT ["init.sh"]

#python/pip - global
#RUN virtualenv /opt/djanker-project/
COPY requirements/djanker.txt /opt/djanker-project/requirements/
RUN pip install --upgrade pip
RUN pip install --exists-action w -r /opt/djanker-project/requirements/djanker.txt

#Copy the rest of the stuff over
COPY . /opt/djanker

# Configure Nginx
RUN ln -s /opt/djanker-project/nginx.conf.template /etc/nginx/sites-enabled/djanker.conf
RUN rm /etc/nginx/sites-enabled/default

# Run Supervisor (i.e., start MySQL, Nginx, and Gunicorn)
RUN ln -s /opt/djanker-project/supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]
