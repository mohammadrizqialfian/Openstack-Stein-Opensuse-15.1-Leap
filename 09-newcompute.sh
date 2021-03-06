#!/bin/bash
source config.conf

echo -e "$red \n\n############## Starting running script Add New Compute Openstack ############## $color_off\n\n"

ssh-copy-id -i ~/.ssh/id_rsa.pub root@$IPCOMPUTE

echo -e "$red \n###Configre Hostname### $color_off"
ssh root@$IPMANAGEMENT "echo -e '$IPCOMPUTE\t $HOSTCOMPUTE' >> /etc/hosts"

ssh root@$IPCOMPUTE << _EOFNEWTEST_
echo -e "$red \n###Configre Hostname### $color_off"
[ -f /etc/hosts.orig ] && cp -v /etc/hosts.orig /etc/hosts
[ ! -f /etc/hosts.orig ] && cp -v /etc/hosts /etc/hosts.orig
echo -e "$IPMANAGEMENT\t $HOSTCONTROLLER" >> /etc/hosts
echo -e "$IPCOMPUTE\t $HOSTCOMPUTE" >> /etc/hosts
echo -e "$red \n###Configre NTP### $color_off"
#### Configure NTP ####
zypper -n install --no-recommends chrony
[ -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf.orig /etc/chrony.conf
[ ! -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf /etc/chrony.conf.orig
sed -i "s/^pool/#pool/" /etc/chrony.d/pool.conf
sed -i "s/^pool/#pool/" /etc/chrony.conf
sed -i "s/^! pool/#pool/" /etc/chrony.conf
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

ssh root@$IPCOMPUTE "cat << _EOF_ > /etc/nova/nova.conf.d/500-nova.conf
[DEFAULT]
enabled_apis = osapi_compute,metadata
compute_driver = libvirt.LibvirtDriver
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT
my_ip = $IPCOMPUTE
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
resume_guests_state_on_host_boot = true

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
##uncomment line dibawah ini jika ingin mengaktifkan nested virtualization
#cpu_mode = host-passthrough

[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $IPCOMPUTE
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

_EOF_"
ssh root@$IPCOMPUTE << _EOFNEWTEST_
## hapus "#nama_proc" untuk mengaktifkan nested virtualization
#intel modprobe -r kvm_intel && modprobe kvm_intel nested=1
#intel echo "options kvm_intel nested=Y" > /etc/modprobe.d/kvm_intel.conf
#amd modprobe -r kvm_amd && modprobe kvm_amd nested=1
#amd echo "options kvm_amd nested=Y" > /etc/modprobe.d/kvm_amd.conf
chown root:nova /etc/nova/nova.conf.d/500-nova.conf
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl restart libvirtd.service openstack-nova-compute.service
modprobe nbd
echo nbd > /etc/modules-load.d/nbd.conf
_EOFNEWTEST_

ssh root@$IPCOMPUTE << _EOFNEWTEST_
zypper -n in --no-recommends openvswitch
systemctl enable openvswitch
systemctl restart openvswitch
if [[ $INTMANAGEMENTCOMPUTE == $INTEXTERNALCOMPUTE ]]
then
cat << _EOF_ > /etc/sysconfig/network/ifcfg-br-ex
BOOTPROTO='static'
NAME='br-ex'
STARTMODE='auto'
OVS_BRIDGE='yes'
OVS_BRIDGE_PORT_DEVICE='$INTMANAGEMENTCOMPUTE'
IPADDR='$IPCOMPUTE'
NETMASK='$NETMASKMANAGEMENTCOMPUTE'
_EOF_
mv /etc/sysconfig/network/ifroute-$INTMANAGEMENTCOMPUTE /etc/sysconfig/network/backup.ifroute-$INTMANAGEMENTCOMPUTE
mv /etc/sysconfig/network/ifcfg-$INTMANAGEMENTCOMPUTE /etc/sysconfig/network/backup.ifcfg-$INTMANAGEMENTCOMPUTE  
echo "default $IPGATEWAYCOMPUTE - br-ex" > /etc/sysconfig/network/ifroute-br-ex
else
mv /etc/sysconfig/network/ifcfg-$INTEXTERNALCOMPUTE /etc/sysconfig/network/backup.ifcfg-$INTEXTERNALCOMPUTE 
cat << _EOF_ > /etc/sysconfig/network/ifcfg-br-ex
BOOTPROTO='none'
NAME='br-ex'
STARTMODE='auto'
OVS_BRIDGE='yes'
OVS_BRIDGE_PORT_DEVICE='$INTEXTERNALCOMPUTE'
_EOF_
fi

cat << _EOF_ > /etc/sysconfig/network/ifcfg-$INTEXTERNALCOMPUTE
STARTMODE='auto'
BOOTPROTO='none'
_EOF_
systemctl restart network
_EOFNEWTEST_

ssh root@$IPCOMPUTE << _EOFNEW_
zypper -n install --no-recommends openstack-neutron-openvswitch-agent

cat << _EOF_ > /etc/neutron/neutron.conf.d/500-neutron.conf
[DEFAULT]
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT
auth_strategy = keystone

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp

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

chown root:neutron /etc/neutron/neutron.conf.d/500-neutron.conf
[ ! -f /etc/neutron/plugins/ml2/openvswitch_agent.ini.orig ] && cp -v /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.orig

cat << _EOF_ > /etc/neutron/plugins/ml2/openvswitch_agent.ini
[DEFAULT]

[agent]
tunnel_types = vxlan
vxlan_udp_port = 4789
l2_population = False
drop_flows_on_start = False

[network_log]

[ovs]
integration_bridge = br-int
tunnel_bridge = br-tun
local_ip = $IPCOMPUTE
bridge_mappings = provider:br-ex

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[xenapi]
_EOF_

_EOFNEW_

ssh root@$IPCOMPUTE << _EOFNEWTEST_
[ -f /etc/nova/nova.conf.d/500-nova.conf.orig ] && cp -v  /etc/nova/nova.conf.d/500-nova.conf.orig /etc/nova/nova.conf.d/500-nova.conf
[ ! -f /etc/nova/nova.conf.d/500-nova.conf.orig ] && cp -v /etc/nova/nova.conf.d/500-nova.conf /etc/nova/nova.conf.d/500-nova.conf.orig
cat << _EOF_ >> /etc/nova/nova.conf.d/500-nova.conf
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
# su -s /bin/sh -c "neutron-db-manage upgrade head" neutron
systemctl enable  openstack-neutron-openvswitch-agent.service 
systemctl restart openstack-neutron-openvswitch-agent.service 
sleep 5
firewall-cmd --permanent --add-port=4789/udp
firewall-cmd --permanent --add-port=9696/tcp
firewall-cmd --permanent --add-port=5900-5999/tcp
firewall-cmd --permanent --add-port 6080/tcp
firewall-cmd --permanent --add-port 6081/tcp
firewall-cmd --permanent --add-port 6082/tcp
firewall-cmd --permanent --add-port 8773-8775/tcp
firewall-cmd --reload

_EOFNEWTEST_


echo -e "$red \n\n############## Completed running script Add New Compute Openstack ############## $color_off\n\n"