#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Cinder ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEW_
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep cinder > /dev/null 2>&1 && echo -e "$red \n ## cinder database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE cinder; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDERDBPASS'; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDERDBPASS';"
source keystonerc_admin
openstack user list | grep cinder > /dev/null 2>&1 && echo -e "$red \n ## cinder user already exists ## $color_off" || openstack user create --domain default --password $CINDERPASS cinder
openstack role add --project service --user cinder admin
openstack service list | grep cinderv2 > /dev/null 2>&1 && echo -e "$red \n ## cinderv2 service already exists ## $color_off" || openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service list | grep cinderv3 > /dev/null 2>&1 && echo -e "$red \n ## cinderv3 service already exists ## $color_off" || openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint list | grep public | grep volumev2 > /dev/null 2>&1 && echo -e "$red \n ## volumev2 public endpoint already exists ## $color_off" ||  openstack endpoint create --region RegionOne volumev2 public http://$IPMANAGEMENT:8776/v2/%\(project_id\)s
openstack endpoint list | grep internal | grep volumev2 > /dev/null 2>&1 &&echo -e "$red \n ## volumev2 internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne volumev2 internal http://$IPMANAGEMENT:8776/v2/%\(project_id\)s
openstack endpoint list | grep admin | grep volumev2 > /dev/null 2>&1 && echo -e "$red \n ## volumev2 admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne volumev2 admin http://$IPMANAGEMENT:8776/v2/%\(project_id\)s
openstack endpoint list | grep public | grep volumev3 > /dev/null 2>&1 && echo -e "$red \n ## volumev3 public endpoint already exists ## $color_off" ||  openstack endpoint create --region RegionOne volumev3 public http://$IPMANAGEMENT:8776/v3/%\(project_id\)s
openstack endpoint list | grep internal | grep volumev3 > /dev/null 2>&1 &&echo -e "$red \n ## volumev3 internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne volumev3 internal http://$IPMANAGEMENT:8776/v3/%\(project_id\)s
openstack endpoint list | grep admin | grep volumev3 > /dev/null 2>&1 && echo -e "$red \n ## volumev3 admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne volumev3 admin http://$IPMANAGEMENT:8776/v3/%\(project_id\)s
_EOFNEW_

ssh root@$IPMANAGEMENT << _EOFNEW_
zypper -n install --no-recommends openstack-cinder-api openstack-cinder-scheduler openstack-cinder-volume tgt lvm2 qemu
pvcreate /dev/$CINDERDEV
vgcreate cinder-volumes /dev/$CINDERDEV

[ ! -f /etc/cinder/cinder.conf.orig ] && cp -v /etc/cinder/cinder.conf /etc/cinder/cinder.conf.orig
cat << _EOF_ > /etc/cinder/cinder.conf.d/010-cinder.conf
[DEFAULT]
log_dir = /var/log/cinder
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT
auth_strategy = keystone
enabled_backends = lvm
glance_api_servers = http://$IPMANAGEMENT:9292
my_ip = $IPMANAGEMENT

[database]
connection = mysql+pymysql://cinder:$CINDERDBPASS@$IPMANAGEMENT/cinder

[keystone_authtoken]
www_authenticate_uri = http://$IPMANAGEMENT:5000
auth_url = http://$IPMANAGEMENT:5000
memcached_servers = $IPMANAGEMENT:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $CINDERPASS

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
_EOF_

cat << _EOF_ >> /etc/nova/nova.conf.d/010-nova.conf

[cinder]
os_region_name = RegionOne
_EOF_

echo "include /var/lib/cinder/volumes/*" > /etc/tgt/conf.d/cinder.conf
systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service tgtd.service
systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service tgtd.service
sleep 10
firewall-cmd --permanent --add-port 3260/tcp
firewall-cmd --permanent --add-port 8776/tcp
firewall-cmd --reload
source keystonerc_admin
openstack volume service list
_EOFNEW_

echo -e "$red \n\n############## Completed running script Openstack Cinder ############## $color_off\n\n"