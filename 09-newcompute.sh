#!/bin/bash
source config.conf

echo -e "$red \n\n############## Starting running script Add New Compute Openstack ############## $color_off\n\n"

ssh-copy-id -i ~/.ssh/id_rsa.pub root@$IPCOMPUTE

echo -e "$red \n###Configre Hostname### $color_off"
ssh root@$IPMANAGEMENT echo -e "$IPCOMPUTE\t $HOSTCOMPUTE" >> /etc/hosts

ssh root@$IPCOMPUTE << _EOFNEWTEST_
echo -e "$IPMANAGEMENT\t $HOSTCONTROLLER" >> /etc/hosts
echo -e "$IPCOMPUTE\t $HOSTCOMPUTE" >> /etc/hosts
echo -e "$red \n###Configre NTP### $color_off"
#### Configure NTP ####
zypper -n install --no-recommends chrony
[ -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf.orig /etc/chrony.conf
[ ! -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf /etc/chrony.conf.orig
echo "server $IPMANAGEMENT iburst" >> /etc/chrony.conf
systemctl enable chronyd.service
systemctl restart chronyd.service
chronyc sources
echo -e "$red \n###Install Openstack Client and adding repositories### $color_off"
#### Configure Repositories ####
[ ! -f /etc/zypp/repos.d/Stein.repo ] && zypper addrepo -f  obs://Cloud:OpenStack:Stein/openSUSE_Leap_15.1 Stein
zypper --gpg-auto-import-keys refresh && zypper -n dist-upgrade
zypper -n install --no-recommends python2-openstackclient openstack-utils
cat << _EOF_ > keystonerc_admin
unset OS_SERVICE_TOKEN
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMINLOG
export PS1='[\u@\h \W(keystone_admin)]\$ '
export OS_AUTH_URL=http://$IPMANAGEMENT:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
_EOF_
[ ! -f /etc/zypp/repos.d/home_Sauerland.repo ] && zypper addrepo https://download.opensuse.org/repositories/home:Sauerland/openSUSE_Leap_15.2/home:Sauerland.repo
zypper --gpg-auto-import-keys refresh && zypper -n dist-upgrade
zypper -n install --no-recommends genisoimage openstack-nova-compute  qemu-kvm libvirt

_EOFNEWTEST_

ssh root@$IPCOMPUTE cat << _EOF_ > /etc/nova/nova.conf.d/010-nova.conf
[DEFAULT]
log_dir = /var/log/nova
bindir = /usr/bin
state_path = /var/lib/nova
enabled_apis = osapi_compute,metadata
compute_driver = libvirt.LibvirtDriver
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT
my_ip = $IPMANAGEMENT
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api]
auth_strategy = keystone

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

[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = \$my_ip
novncproxy_base_url = http://$IPMANAGEMENT:6080/vnc_auto.html

[glance]
api_servers = http://$IPMANAGEMENT:9292

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

_EOF_

_EOFNEWTEST_

ssh root@$IPCOMPUTE modprobe nbd
ssh root@$IPCOMPUTE echo nbd > /etc/modules-load.d/nbd.conf

ssh root@$IPCOMPUTE << _EOFNEW_
zypper -n install --no-recommends openstack-neutron-linuxbridge-agent bridge-utils

[ ! -f /etc/neutron/neutron.conf.orig ] && cp -v /etc/neutron/neutron.conf /etc/neutron/neutron.conf.orig
[ ! -f /etc/neutron/neutron.conf.d/010-neutron.conf.orig ] && cp -v /etc/neutron/neutron.conf.d/010-neutron.conf /etc/neutron/neutron.conf.d/010-neutron.conf.orig
cat << _EOF_ > /etc/neutron/neutron.conf.d/010-neutron.conf
[DEFAULT]
state_path = /var/lib/neutron
log_dir = /var/log/neutron
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT
auth_strategy = keystone

[agent]
root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf

[oslo_concurrency]
lock_path = /var/run/neutron

[keystone_authtoken]
www_authenticate_uri = http://$IPMANAGEMENT:5000
auth_url = http://$IPMANAGEMENT:5000
memcached_servers = $IPMANAGEMENT:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $NEUTRONPASS

_EOF_


[ ! -f /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig ] && cp -v /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig

cat << _EOF_ > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
[DEFAULT]

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

[linux_bridge]
physical_interface_mappings = provider:$INTEXTERNAL

[vxlan]
enable_vxlan = true
local_ip = $IPCOMPUTE
l2_population = true
_EOF_

modprobe br_netfilter
echo 'br_netfilter' > /etc/modules-load.d/netfilter.conf
lsmod | grep netfilter
sysctl -a | grep bridge

_EOFNEW_

ssh root@$IPCOMPUTE << _EOFNEWTEST_
cat << _EOF_ >> /etc/nova/nova.conf.d/010-nova.conf
[neutron]
url = http://$IPMANAGEMENT:9696
auth_url = http://$IPMANAGEMENT:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRONPASS
_EOF_

echo 'NEUTRON_PLUGIN_CONF="/etc/neutron/plugins/ml2/ml2_conf.ini"' >> /etc/sysconfig/neutron
ln -s /etc/apparmor.d/usr.sbin.dnsmasq /etc/apparmor.d/disable/
systemctl stop apparmor
systemctl disable apparmor
systemctl restart openstack-nova-compute.service
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf.d/010-neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
systemctl enable  openstack-neutron-linuxbridge-agent.service 
systemctl restart openstack-neutron-linuxbridge-agent.service 
sleep 5
firewall-cmd --permanent --add-port=9696/tcp
firewall-cmd --permanent --add-port=5900-5999/tcp
firewall-cmd --permanent --add-port 6080/tcp
firewall-cmd --permanent --add-port 6081/tcp
firewall-cmd --permanent --add-port 6082/tcp
firewall-cmd --permanent --add-port 8773-8775/tcp
firewall-cmd --reload

_EOFNEWTEST_


echo -e "$red \n\n############## Completed running script Add New Compute Openstack ############## $color_off\n\n"