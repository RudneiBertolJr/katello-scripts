#!/bin/bash
STATE=""
USER='admin'
PWD='Z4LfJ8Wxf2bPjfG2NmDMo3VihKXYbCAb'
pulp-admin login -u ${USER} -p ${PWD}
for TASK in `pulp-admin -u ${USER} -p ${PWD} tasks list | egrep '^Task Id:|^State:' | sed -e 's,^Task Id: ,,' -e 's,^State: ,,'`; do
        if [ "$STATE" = "" ]; then
                STATE=$TASK
        else
                if [ $STATE != Successful ] && [ $STATE != Cancelled ] && [ $STATE != Failed ]; then
                        pulp-admin tasks details --task-id=$TASK
                        pulp-admin tasks cancel --task-id=$TASK
                fi
                STATE=""
        fi
done
pulp-admin logout
