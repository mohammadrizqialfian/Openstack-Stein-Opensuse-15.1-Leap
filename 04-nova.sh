#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Nova ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

source keystonerc_admin
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep nova_api > /dev/null 2>&1 && echo -e "$red \n ## nova_api database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE nova_api; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVADBPASS'; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVADBPASS';"
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep -w nova > /dev/null 2>&1 && echo -e "$red \n ## nova database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE nova; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVADBPASS'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVADBPASS';"
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep nova_cell0 > /dev/null 2>&1 && echo -e "$red \n ## nova_cell0 database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE nova_cell0; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVADBPASS'; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVADBPASS';"
openstack user list | grep nova > /dev/null 2>&1 && echo -e "$red \n ## nova user already exists ## $color_off" || openstack user create --domain default --password $NOVAPASS nova
openstack role add --project service --user nova admin
openstack service list | grep nova > /dev/null 2>&1 && echo -e "$red \n ## nova service already exists ## $color_off" || openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint list | grep public | grep nova > /dev/null 2>&1 && echo -e "$red \n ## nova public endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne compute public http://$IPMANAGEMENT:8774/v2.1
openstack endpoint list | grep internal | grep nova > /dev/null 2>&1 && echo -e "$red \n ## nova internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne compute internal http://$IPMANAGEMENT:8774/v2.1
openstack endpoint list | grep admin | grep nova > /dev/null 2>&1 && echo -e "$red \n ## nova admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne compute admin http://$IPMANAGEMENT:8774/v2.1


_EOFNEWTEST_

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

[ ! -f /etc/zypp/repos.d/home_Sauerland.repo ] && zypper addrepo https://download.opensuse.org/repositories/home:Sauerland/openSUSE_Leap_15.2/home:Sauerland.repo
zypper --gpg-auto-import-keys refresh && zypper -n dist-upgrade
zypper -n install --no-recommends genisoimage
zypper -n install --no-recommends openstack-nova-api openstack-nova-scheduler openstack-nova-conductor openstack-nova-consoleauth openstack-nova-novncproxy iptables openstack-nova-compute qemu-kvm libvirt 
_EOFNEWTEST_

ssh root@$IPMANAGEMENT " cat << _EOF_ > /etc/nova/nova.conf.d/500-nova.conf
[DEFAULT]
compute_driver = libvirt.LibvirtDriver
resume_guests_state_on_host_boot = true
my_ip = $IPMANAGEMENT
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT

[api]
auth_strategy = keystone

[api_database]
connection = mysql+pymysql://nova:$NOVADBPASS@$IPMANAGEMENT/nova_api

[database]
connection = mysql+pymysql://nova:$NOVADBPASS@$IPMANAGEMENT/nova

[glance]
api_servers = http://$IPMANAGEMENT:9292

[keystone_authtoken]
auth_url = http://$IPMANAGEMENT:5000/
memcached_servers = $IPMANAGEMENT:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVAPASS

[libvirt]
virt_type = $TYPEVIRT
##uncomment line dibawah ini jika ingin mengaktifkan nested virtualization
#cpu_mode=host-passthrough

[oslo_concurrency]
lock_path = /var/run/nova

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://$IPMANAGEMENT:5000/v3
username = placement
password = $PLACEMENTPASS

[scheduler]
discover_hosts_in_cells_interval = 300

[vnc]
enabled = true
server_listen = $IPMANAGEMENT
server_proxyclient_address = $IPMANAGEMENT
novncproxy_base_url = http://$IPMANAGEMENT:6080/vnc_auto.html
_EOF_"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
chown root:nova /etc/nova/nova.conf.d/500-nova.conf
## hapus "#nama_proc" untuk mengaktifkan nested virtualization
#intel modprobe kvm_intel nested=1
#intel echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm.conf
#amd modprobe kvm_amd nested=1
#amd echo "options kvm_amd nested=1" > /etc/modprobe.d/kvm.conf
modprobe nbd
echo nbd > /etc/modules-load.d/nbd.conf


su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

systemctl enable openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service
systemctl restart openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  libvirtd.service openstack-nova-compute.service 
sleep 5
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
nova-manage cell_v2 simple_cell_setup

firewall-cmd --permanent --add-port=5900-5999/tcp
firewall-cmd --permanent --add-port 6080-6082/tcp
firewall-cmd --permanent --add-port 8774-8775/tcp
firewall-cmd --reload

source keystonerc_admin
openstack hypervisor list
openstack compute service list --service nova-compute
openstack catalog list
nova-status upgrade check

_EOFNEWTEST_

echo -e "$red \n\n############## Completed running script Openstack Nova ############## $color_off\n\n"