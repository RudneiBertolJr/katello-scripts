#!/bin/bash
USERNAME='admin'
PASSWORD='Z4LfJ8Wxf2bPjfG2NmDMo3VihKXYbCAb'
wget -N http://cefs.steve-meier.de/errata.latest.xml
wget -N https://www.redhat.com/security/data/oval/com.redhat.rhsa-all.xml
errata_import.pl --errata=errata.latest.xml --rhsa-oval=com.redhat.rhsa-all.xml --user=${USERNAME} --password=${PASSWORD}

