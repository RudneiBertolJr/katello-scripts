#!/bin/bash
USERNAME='admin'
PASSWORD=$(grep -i ^default_password /etc/pulp/server.conf | awk '{print $2}')
wget -N http://cefs.steve-meier.de/errata.latest.xml
wget -N https://www.redhat.com/security/data/oval/com.redhat.rhsa-all.xml
errata_import.pl --errata=errata.latest.xml --rhsa-oval=com.redhat.rhsa-all.xml --user=${USERNAME} --password=${PASSWORD}
