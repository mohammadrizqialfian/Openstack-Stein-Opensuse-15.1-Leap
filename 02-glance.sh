#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Glance ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

source keystonerc_admin
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep glance > /dev/null 2>&1 && echo -e "$red \n## glance database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCEDBPASS'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCEDBPASS';"
openstack user list | grep glance > /dev/null 2>&1 && echo -e "$red \n## glance user already exists ## $color_off" || openstack user create --domain default --password $GLANCEPASS glance
openstack role add --project service --user glance admin
openstack service list | grep glance > /dev/null 2>&1 && echo -e "$red \n ## glance service already exists ## $color_off" || openstack service create --name glance --description "OpenStack Image service" image
openstack endpoint list | grep public | grep glance > /dev/null 2>&1 && echo -e "$red \n ## glance public endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne image public http://$IPMANAGEMENT:9292
openstack endpoint list | grep internal | grep glance > /dev/null 2>&1 && echo -e "$red \n ## glance internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne image internal http://$IPMANAGEMENT:9292
openstack endpoint list | grep admin | grep glance > /dev/null 2>&1 && echo -e "$red \n ## glance admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne image admin http://$IPMANAGEMENT:9292

_EOFNEWTEST_

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

zypper -n install --no-recommends openstack-glance openstack-glance-api 

cat << _EOF_ > /etc/glance/glance-api.conf.d/500-glance-api.conf
[database]
connection = mysql+pymysql://glance:$GLANCEDBPASS@$IPMANAGEMENT/glance

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images

[keystone_authtoken]
www_authenticate_uri = http://$IPMANAGEMENT:5000
auth_url = http://$IPMANAGEMENT:5000
memcached_servers = $IPMANAGEMENT:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCEPASS

[paste_deploy]
flavor = keystone

_EOF_

systemctl enable openstack-glance-api.service 
systemctl restart openstack-glance-api.service 
sleep 5
firewall-cmd --permanent --add-port=9292/tcp
firewall-cmd --reload

source keystonerc_admin
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

_EOFNEWTEST_

echo -e "$red \n\n############## Completed running script Openstack Glance ############## $color_off\n\n"