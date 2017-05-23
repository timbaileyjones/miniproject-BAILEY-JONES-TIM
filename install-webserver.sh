#!/bin/bash -e
set -e
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
	SG_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Server-Security-Group" --vpc-id $VPC_ID --output text)
	aws ec2 authorize-security-group-ingress \
		--group-id $SG_ID \
		--ip-permissions "$IP_PERMISSIONS" 
fi
echo $SG_ID >> .security_group_ids

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
echo "$INSTANCE_ID is up at $PUBLIC_HOSTNAME"

echo waiting for ssh daemon to listen to port 22
set +e
./wait-for-port-to-listen.py $PUBLIC_HOSTNAME 22 30
if [ $? -ne 0 ]
then
	echo "sshd isn't listening after 30 seconds, aborting...!"
	exit 1
fi
set -e

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

echo checking to see if content is correctly installed.
set +e
curl -q http://$PUBLIC_HOSTNAME 2>&1 | grep Automation >/dev/null
if [ $? -ne 0 ]
then
	echo "index.html at $PUBLIC_HOSTNAME didn't contain the word Automation"
	exit 1
fi
echo "Web Server with content successfully deployed at http://$PUBLIC_HOSTNAME"
exit 0
