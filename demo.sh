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
openstack flavor create --public m1.nano --ram 128 --id auto --disk 1 --vcpus 1
openstack flavor create --public m1.micro --ram 256 --id auto --disk 2 --vcpus 1
openstack flavor create --public m1.tiny --ram 512 --id auto --disk 5 --vcpus 1
openstack flavor create --public m1.small --ram 1024 --id auto --disk 10 --swap 1024 --vcpus 1
openstack flavor create --public m1.medium --ram 2048 --id auto --disk 15 --swap 2048 --vcpus 1
openstack flavor create --public m1.large --ram 4096 --id auto --disk 20 --ephemeral 5 --vcpus 2
openstack flavor create --public m1.xlarge --ram 8192 --id auto --disk 80 --ephemeral 10 --vcpus 4
openstack flavor create --public m1.jumbo --ram 16384 --id auto --disk 160 --ephemeral 20 --vcpus 8
openstack flavor list

openstack project create --domain default --description "Demo Project" $NAMA_PROJECT
openstack user create --domain default --password $PASS_USER $NAMA_USER
# openstack role create compute-user
# openstack role add --project $NAMA_PROJECT --user $NAMA_USER compute-user
openstack role add --project $NAMA_PROJECT --user $NAMA_USER user
openstack quota set --cores 2 --instances 4 --ram 4096 $NAMA_PROJECT
openstack network create public-net --external --share --provider-network-type flat --provider-physical-network provider
openstack subnet create --subnet-range $SUBNET_PUB --dhcp --gateway $GATEWAY_PUB --allocation-pool start=$START_PUB,end=$END_PUB --dns-nameserver 8.8.8.8 --network public-net public-sub

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
openstack keypair create demo-key > demo-key.pem
chmod 600 demo-key.pem
openstack router create router-demo
openstack network create private-net
openstack subnet create --subnet-range 192.168.1.0/24 --dhcp --dns-nameserver 8.8.8.8 --network private-net private-sub
openstack router add subnet router-demo private-sub
openstack router set router-demo --external-gateway public-net
openstack security group rule create --protocol tcp --dst-port 22 default
openstack security group rule create --protocol tcp --dst-port 80 default
openstack security group rule create --protocol icmp default
# openstack volume create --size 5 vol-demo
# openstack snapshot create --name vol-demo-snap vol-demo
# openstack volume create --size 5 --snapshot vol-demo-snap vol-demo-snap-vol
# openstack volume list
# openstack snapshot list
openstack server create --image cirros --flavor m1.tiny --key-name demo-key --network public-net --wait demo-pub-instance
openstack server create --image cirros --flavor m1.tiny --key-name demo-key --network private-net --wait demo-priv-instance
# openstack server delete demo-pub-instance
# openstack server delete demo-priv-instance
# openstack port create --fixed-ip ip-address=192.168.1.100 --network private-net port1
# openstack server create --image cirros --flavor m1.tiny --key-name demo-key --port port1 --wait demo-priv-instance2
# openstack server add volume demo-priv-instance2 vol-demo
# openstack console log show demo-priv-instance2
# openstack console url show demo-priv-instance2
# openstack server list
openstack floating ip create public-net
### MAnual
#openstack server add floating ip demo-priv-instance #ip_floating 
#ssh -i demo-key.pem cirros@#ip_floating
# openstack container create files
# mkdir folder
# echo 'file yang diupload' > folder/upload
# openstack object create files folder/upload
# echo 'file test' > test
# openstack object create files test
# openstack container list
# openstack object list files
# openstack object save files/folder upload 
# openstack object save files test --file folder/test
# md5sum test
#  find /srv/ -type f -exec md5sum {} + | grep 'md5sum-files'
# cat << _EOF_ > index.html
#<html>
#<head>
#<title> Mencoba </title>
#</head>
#<body>
#<h1> Mohammad Rizqi Alfian</h1>
#</body>
#</html>
#_EOF_
# openstack object create files index.html
# swift post files --read-acl ".r:*,.rlistings"
# cat << _EOF_ > install_apache
#!/bin/bash
#apt update
#apt -y install apache2
#systemctl enable apache2 --now
#cd /var/www/html
#curl -O http://$IPOPENSTACK:8080/v1/AUTH_$PROJECT_ID/files/index.html
#_EOF_
# openstack server create --image ubuntu --flavor m1.small --key-name demo-key --network public-net --user-data install_apache --wait demo-web-instance