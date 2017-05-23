#!/bin/bash
set -e 
if [ -f .instance_ids ]
then
    # in case there's ever more than one'
    # sort -u is to remove duplicate IDs
    instance_ids="" 
    for instance_id in `cat .instance_ids | sort -u `  
    do
        echo terminating ec2 instance $instance_id
        aws ec2 terminate-instances --instance-ids $instance_id
        instance_ids=$instance_ids" "$instance_id
    done
    echo waiting for the following instances to be terminated: $instance_ids
    aws ec2 wait instance-terminated --instance-ids $instance_ids
    rm .instance_ids 
else
    echo No Instances to terminate...
fi

if [ -f .security_group_ids ]
then
    # in case there's ever more than one'
    # sort -u is to remove duplicate IDs
    for sgid in `cat .security_group_id | sort -u `
    do
        echo deleting previous security group ID  $sgid
        aws ec2 delete-security-group --group-id $sgid
    done
    rm .security_group_ids
else 
    echo No Security Groups to delete...
fi
