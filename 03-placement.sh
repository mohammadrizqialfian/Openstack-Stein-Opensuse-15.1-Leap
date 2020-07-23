#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Placement ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE placement; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$PLACEMENTDBPASS'; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$PLACEMENTDBPASS';"
source keystonerc_admin
openstack user list | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement user already exists ## $color_off" || openstack user create --domain default --password $PLACEMENTPASS placement
openstack role add --project service --user placement admin
openstack service list | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement service already exists ## $color_off" || openstack service create --name placement --description "Placement API" placement
openstack endpoint list | grep public | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement public endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne placement public http://$IPMANAGEMENT:8778
openstack endpoint list | grep internal | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne placement internal http://$IPMANAGEMENT:8778
openstack endpoint list | grep admin | grep placement > /dev/null 2>&1 && echo -e "$red \n ## placement admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne placement admin http://$IPMANAGEMENT:8778


_EOFNEWTEST_

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

zypper -n install --no-recommends openstack-placement-api

cat << _EOF_ > /etc/placement/placement.conf.d/500-placement.conf
[api]
auth_strategy = keystone

[keystone_authtoken]
auth_url = http://$IPMANAGEMENT:5000/v3
memcached_servers = $IPMANAGEMENT:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = $PLACEMENTPASS

[placement_database]
connection = mysql+pymysql://placement:$PLACEMENTDBPASS@$IPMANAGEMENT/placement
_EOF_
chown root:placement /etc/placement/placement.conf.d/500-placement.conf
su -s /bin/sh -c "placement-manage db sync" placement
cp -v /etc/apache2/vhosts.d/openstack-placement-api.conf.sample /etc/apache2/vhosts.d/openstack-placement-api.conf
sed -i "s/8780/8778/" /etc/apache2/vhosts.d/openstack-placement-api.conf
firewall-cmd --permanent --add-port 8778/tcp
firewall-cmd --reload
systemctl reload apache2.service
source keystonerc_admin
placement-status upgrade check

_EOFNEWTEST_

echo -e "$red \n\n############## Completed running script Openstack Placement ############## $color_off\n\n"
