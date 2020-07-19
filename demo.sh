#!/bin/bash
## salin file ini ke tempat keysonerc_admin berada(defaultnya berada di home directory root)
source keystonerc_admin

NAMA_PROJECT=demo-project
NAMA_USER=demo
PASS_USER=passdemo
IPOPENSTACK=192.168.137.10
SUBNET_PUB=192.168.137.0/24
GATEWAY_PUB=192.168.137.1
START_PUB=192.168.137.50
END_PUB=192.168.137.100


##Optional
# openstack domain create --description "An Example Domain" example
# openstack role create myrole
#USERNAME='rizqi alfian'
#for USER in $USERNAME
#do
#    openstack project create $USER --domain default
#    openstack user create --project $USER --password $USER $USER
#done
##

###Add Flavor###
openstack flavor create --public m1.nano --ram 64 --id auto --disk 1 --vcpus 1
openstack flavor create --public m1.tiny --ram 512 --id auto --disk 1 --vcpus 1
openstack flavor create --public m1.xsmall --ram 1024 --id auto --disk 10 --vcpus 1
openstack flavor create --public m1.small --ram 2048 --id auto --disk 15 --vcpus 1
openstack flavor create --public m1.medium --ram 4096 --id auto --disk 20 --vcpus 2
openstack flavor create --public m1.large --ram 8192 --id auto --disk 80 --vcpus 4
openstack flavor create --public m1.xlarge --ram 16384 --id auto --disk 160 --vcpus 8
openstack flavor list

openstack project create --domain default --description "Demo Project" $NAMA_PROJECT
openstack user create --domain default --password $PASS_USER $NAMA_USER
openstack role add --project $NAMA_PROJECT --user $NAMA_USER user
openstack network create public-net --external --share --provider-network-type flat --provider-physical-network provider
openstack subnet create --subnet-range $SUBNET_PUB --no-dhcp --gateway $GATEWAY_PUB --allocation-pool start=$START_PUB,end=$END_PUB --network public-net public-sub

cat << _EOF_ > keystonerc_$NAMA_USER
unset OS_SERVICE_TOKEN
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=$NAMA_PROJECT
export OS_USERNAME=$NAMA_USER
export OS_PASSWORD=$PASS_USER
export PS1='[\u@\h \W(keystone_$NAMA_USER)]\$ '
export OS_AUTH_URL=http://$IPOPENSTACK:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
_EOF_

source keystonerc_$NAMA_USER
openstack keypair create demo > demo.pem
chmod 600 demo.pem
openstack router create router-demo
openstack network create private-net
openstack subnet create --subnet-range 192.168.1.0/24 --dhcp --network private-net private-sub
openstack router add subnet router-demo private-sub
openstack router set router-demo --external-gateway public-net
openstack security group rule create --protocol tcp --dst-port 22 default
openstack security group rule create --protocol icmp default
openstack server create --image cirros --flavor m1.tiny --key-name demo --network public-net --wait demo-pub-instance
openstack server create --image cirros --flavor m1.tiny --key-name demo --network private-net --wait demo-priv-instance
openstack floating ip create public-net
### MAnual
openstack server add floating ip #ip_dari_command_sebelumnya 
ssh -i demo.pem cloud-user@#ip_dari_command_sebelumnya