#!/bin/bash -e
set -x
KEY_FILE=us-east-2-ohio-key-pair
STATIC_SITE=./static_site 
SECURITY_GROUP_NAME=ohio-security-group
IP_PERMISSIONS='[
    {"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}, 
    {"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
]'
	chmod 600 *.pem 

	AMAZON_IMAGE_ID=$(aws ec2 describe-images \
		--filters "Name=description, Values=Amazon Linux AMI 2017.03.?.20170417 x86_64 HVM GP2" \
		--query "Images[0].ImageId" \
		--output text)

	VPC_ID=$(aws ec2 describe-vpcs \
		--filter "Name=isDefault, Values=true" \
		--query "Vpcs[0].VpcId" \
		--output text)
	echo $VPC_ID > .vpc_id

	SUBNET_ID=$(aws ec2 describe-subnets \
		--filters "Name=vpc-id, Values=$VPC_ID" \
		--query "Subnets[0].SubnetId" \
		--output text)

	echo search for existing security group
	SG_ID=$(aws ec2 describe-security-groups  \
		--filters="Name=group-name, Values=$SECURITY_GROUP_NAME" \
		--query "SecurityGroups[0].GroupId" \
		--output text) 

	if [ -z $SG_ID -o $SG_ID = None ]
	then
		echo "Couldn't find security group for $SECURITY_GROUP_NAME, creating one..."
		SG_ID=$(aws ec2 create-security-group --group-name server-security-group --description "Server-Security-Group" --vpc-id $VPC_ID --output text)
	fi
	echo $SG_ID >> .security_group_id

	aws ec2 authorize-security-group-ingress \
	    --group-id $SG_ID \
	    --ip-permissions "$IP_PERMISSIONS" 

	INSTANCE_ID=$(aws ec2 run-instances \
		--image-id $AMAZON_IMAGE_ID \
		--key-name $KEY_FILE \
		--instance-type t2.micro \
		--security-group-ids $SG_ID \
		--subnet-id $SUBNET_ID \
		--query "Instances[0].InstanceId" \
		--output text)
	echo "waiting for $INSTANCE_ID ..." 
	aws ec2 wait instance-running --instance-ids $INSTANCE_ID
	
	PUBLIC_HOSTNAME=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicDnsName" --output text)

	echo $INSTANCE_ID >> .instance_ids
	echo "$INSTANCE_ID is accepting SSH connections under $PUBLIC_HOSTNAME"


	sleep 20  # the instance sometimes isn't really ready yet.
	echo installing nginx on $PUBLIC_HOSTNAME
	ssh -i $KEY_FILE.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_HOSTNAME \
		sudo yum -y install nginx


	echo starting nginx on $PUBLIC_HOSTNAME
	ssh -i $KEY_FILE.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_HOSTNAME \
		sudo service nginx start
	ssh -i $KEY_FILE.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_HOSTNAME \
		sudo chown -R ec2-user /usr/share/nginx/html

echo installing content on $PUBLIC_HOSTNAME
rsync -r -e "ssh -i $KEY_FILE.pem" $STATIC_SITE/* ec2-user@$PUBLIC_HOSTNAME:/usr/share/nginx/html/


