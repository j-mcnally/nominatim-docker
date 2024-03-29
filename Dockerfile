FROM ubuntu:xenial
MAINTAINER dorukozturk <dorukozturk@kitware.com>

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

RUN apt-get -y update -qq && \
    apt-get -y install locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    apt-get install -y build-essential cmake g++ libboost-dev libboost-system-dev \
    libboost-filesystem-dev libexpat1-dev zlib1g-dev libxml2-dev\
    libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev \
    postgresql-server-dev-9.5 postgresql-9.5-postgis-2.2 postgresql-contrib-9.5 \
    apache2 php php-pgsql libapache2-mod-php php-pear php-db \
    php-intl git curl sudo \
    python-pip libboost-python-dev \
    osmosis \
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

WORKDIR /app

# Configure postgres
RUN echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/9.5/main/pg_hba.conf && \
    echo "listen_addresses='*'" >> /etc/postgresql/9.5/main/postgresql.conf

# Nominatim install
ENV NOMINATIM_VERSION v3.1.0

RUN pip install osmium && git clone --branch $NOMINATIM_VERSION --depth 1 https://github.com/openstreetmap/Nominatim ./src
RUN cd ./src && git checkout tags/$NOMINATIM_VERSION && git submodule update --init && \
    mkdir build && cd build && cmake .. && make

# Apache configure
COPY local.php /app/src/build/settings/local.php
COPY nominatim.conf /etc/apache2/sites-enabled/000-default.conf

# Load initial data
RUN useradd -m nominatim && \
    chown -R nominatim:nominatim ./src
    
EXPOSE 5432
EXPOSE 8080

COPY wait-for-it.sh /app/wait-for-it.sh
COPY start.sh /app/start.sh
CMD /app/start.sh
