#!/bin/bash
source keystonerc_admin

IPOPENSTACK=172.16.52.2
SUBNET_PUB=172.16.52.0/24
GATEWAY_PUB=172.16.52.1
START_PUB=172.16.52.50
END_PUB=172.16.52.150

openstack group create --description "Demo Group" grub-demo

USERNAME='rizqi alfian'
for USER in $USERNAME
do
    openstack user create --password $USER $USER
	openstack group add user grub-demo $USER
	cat << _EOF_ > keystonerc_$USER
unset OS_SERVICE_TOKEN
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo-project
export OS_USERNAME=$USER
export OS_PASSWORD=$USER
export PS1='[\u@\h \W(keystone_$USER)]\$ '
export OS_AUTH_URL=http://$IPOPENSTACK:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
_EOF_
done

openstack role create demo
openstack project create --description "Project Demo" demo-project
openstack role add --group grub-demo --project demo-project user
openstack quota set --cores 4 --instances 4 --ram 4096 demo-project
openstack flavor create --public m1.nano --ram 128 --disk 1 --vcpus 1
openstack flavor create --public m1.micro --ram 256 --disk 2 --vcpus 1
openstack flavor create --public m1.tiny --ram 512 --disk 5 --vcpus 1
openstack flavor create --public m1.small --ram 1024 --disk 10 --vcpus 1
openstack flavor create --public m1.medium --ram 2048 --disk 20 --vcpus 1
openstack flavor create --public m1.large --ram 4096 --disk 40 --vcpus 2
openstack flavor create --public m1.xlarge --ram 8192 --disk 80 --vcpus 4
openstack flavor create --public m1.jumbo --ram 16384 --disk 160 --vcpus 8

openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/ubuntu-16.04-server-cloudimg-amd64-disk1.img Ubuntu-16.04
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/bionic-server-cloudimg-amd64.img Ubuntu-18.04
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/ubuntu-20.04-server-cloudimg-amd64.img Ubuntu-20.04
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/CentOS-7-x86_64-GenericCloud-1907.qcow2 Centos-7
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2 Centos-8
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/debian-10.3.0-openstack-amd64.qcow2 Debian-10
openstack image create --container-format bare --disk-format qcow2 --protected --public --file /home/proditk/openSUSE-Leap-15.1-JeOS.x86_64-15.1.0-OpenStack-Cloud-Current.qcow2 OpenSUSE-15.1
openstack image create --container-format bare --disk-format iso --protected --public --file /home/proditk/en_windows_server_2016_updated_feb_2018_x64_dvd_11636692.iso Windows-Server-2016

openstack network create external --external --share --provider-network-type flat --provider-physical-network provider
openstack subnet create --subnet-range $SUBNET_PUB --dhcp --gateway $GATEWAY_PUB --allocation-pool start=$START_PUB,end=$END_PUB --dns-nameserver 8.8.8.8 --network external external-sub
openstack floating ip create external --floating-ip-address 172.16.52.117 --project demo-project
openstack floating ip create external --floating-ip-address 172.16.52.107 --project demo-project

source keystonerc_alfian

openstack network create network1-demo
openstack subnet create --subnet-range 192.168.1.0/24 --dhcp --allocation-pool start=192.168.1.100,end=192.168.1.200 --dns-nameserver 8.8.8.8 --dns-nameserver 1.1.1.1 --network network1-demo network1-sub-demo
openstack network create network2-demo
openstack subnet create --subnet-range 10.10.10.0/24 --dhcp --dns-nameserver 8.8.8.8 --network network2-demo network2-sub-demo

openstack router create router-demo
openstack router set router-demo --external-gateway external
openstack router add subnet router-demo network1-sub-demo 
openstack router add subnet router-demo network2-sub-demo

openstack security group create --description "Demo Security Group" demo-sg
openstack security group rule create --protocol tcp --dst-port 22 demo-sg
openstack security group rule create --protocol tcp --dst-port 80 demo-sg
openstack security group rule create --protocol icmp demo-sg

openstack keypair create demo-key > demo-key.pem
chmod 600 demo-key.pem
openstack keypair create --public-key /home/proditk/server.pub alfian-key

openstack volume create --size 5 --description "volume demo" vol-demo

openstack container create demo
swift post demo --read-acl ".r:*,.rlistings"
# md5sum test
#  find /srv/ -type f -exec md5sum {} + | grep 'md5sum-files'
cd /home/proditk/
openstack object create demo "All-in-One node.jpg"
openstack object create demo "test/Flow neutron.jpg"
cd

openstack server create --image Ubuntu-16.04 --flavor m1.small --key-name demo-key --network network1-demo --security-group demo-sg --wait instance1-demo
openstack server add floating ip instance1-demo 172.16.52.117
openstack server add volume instance1-demo vol-demo

openstack port create --fixed-ip ip-address=192.168.1.10 --network network1-demo port1
openstack server create --image Centos-8 --flavor m1.small --key-name demo-key --port port1 --security-group demo-sg --wait instance2-demo
openstack server create --image cirros --flavor m1.micro --key-name demo-key --network network2-demo --security-group demo-sg --wait instance3-demo
openstack server add floating ip instance3-demo 172.16.52.107
openstack server create --image cirros --flavor m1.micro --key-name demo-key --network external --security-group demo-sg --wait instance4-demo
