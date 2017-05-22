#!/bin/bash
set -e 
if [ -f .instance_ids ]
then
    for instance_id in `cat .instance_ids`  # in case there's ever more than one'
    do
        echo terminating ec2 instance $instance_id
        aws ec2 terminate-instances --instance-ids $instance_id
        aws ec2 wait instance-terminated --instance-ids $instance_id
    done
    rm .instance_ids 
else
    echo No Instances to terminate...
fi

if [ -f .security_group_id ]
then
    for sgid in `cat .security_group_id` 
    do
        echo deleting previous security group ID  $sgid
        aws ec2 delete-security-group --group-id $sgid
    done
    rm .security_group_id 
else 
    echo No Security Groups to terminate...
fi
