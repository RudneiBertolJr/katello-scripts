#!/bin/bash
STATE=""
USER='admin'
PWD=$(grep -i ^default_password /etc/pulp/server.conf | awk '{print $2}')
for TASK in `pulp-admin -u ${USER} -p ${PWD} tasks list | egrep '^Task Id:|^State:' | sed -e 's,^Task Id: ,,' -e 's,^State: ,,'`; do
        if [ "$STATE" = "" ]; then
                STATE=$TASK
        else
                if [ $STATE != Successful ] && [ $STATE != Cancelled ] && [ $STATE != Failed ]; then
                        pulp-admin -u ${USER} -p ${PWD} tasks details --task-id=$TASK
                        pulp-admin -u ${USER} -p ${PWD} tasks cancel --task-id=$TASK
                fi
                STATE=""
        fi
done
