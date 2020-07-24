#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Neutron ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
zypper -n in --no-recommends openvswitch
systemctl enable openvswitch
systemctl restart openvswitch
if [[ $INTMANAGEMENT == $INTEXTERNAL ]]
then
cat << _EOF_ > /etc/sysconfig/network/ifcfg-br-ex
BOOTPROTO='static'
NAME='br-ex'
STARTMODE='auto'
OVS_BRIDGE='yes'
OVS_BRIDGE_PORT_DEVICE='$INTMANAGEMENT'
IPADDR='$IPMANAGEMENT'
NETMASK='$NETMASKMANAGEMENT'
_EOF_
mv /etc/sysconfig/network/ifroute-$INTMANAGEMENT /etc/sysconfig/network/backup.ifroute-$INTMANAGEMENT
mv /etc/sysconfig/network/ifcfg-$INTMANAGEMENT /etc/sysconfig/network/backup.ifcfg-$INTMANAGEMENT  
echo "default $IPGATEWAY - br-ex" > /etc/sysconfig/network/ifroute-br-ex
else

mv /etc/sysconfig/network/ifcfg-$INTEXTERNAL /etc/sysconfig/network/backup.ifcfg-$INTEXTERNAL 
cat << _EOF_ > /etc/sysconfig/network/ifcfg-br-ex
BOOTPROTO='none'
NAME='br-ex'
STARTMODE='auto'
OVS_BRIDGE='yes'
OVS_BRIDGE_PORT_DEVICE='$INTEXTERNAL'
_EOF_
fi

cat << _EOF_ > /etc/sysconfig/network/ifcfg-$INTEXTERNAL
STARTMODE='auto'
BOOTPROTO='none'
_EOF_
systemctl restart network
_EOFNEWTEST_

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
source keystonerc_admin
mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE neutron; GRANT ALL PRIVILEGES ON neutron.* TO 'nutron'@'localhost' IDENTIFIED BY '$NEUTRONDBPASS'; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRONDBPASS';"
openstack user list | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron user already exists ## $color_off" || openstack user create --domain default --password $NEUTRONPASS neutron
openstack role add --project service --user neutron admin
openstack service list | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron service already exists ## $color_off" || openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint list | grep public | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron public endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne network public http://$IPMANAGEMENT:9696
openstack endpoint list | grep internal | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne network internal http://$IPMANAGEMENT:9696
openstack endpoint list | grep admin | grep neutron > /dev/null 2>&1 && echo -e "$red \n ## neutron admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne network admin http://$IPMANAGEMENT:9696

_EOFNEWTEST_

ssh root@$IPMANAGEMENT << _EOFNEW_
zypper -n install --no-recommends  openstack-neutron openstack-neutron-server openstack-neutron-dhcp-agent openstack-neutron-metadata-agent openstack-neutron-l3-agent   openstack-neutron-openvswitch-agent
cat << _EOF_ > /etc/neutron/neutron.conf.d/500-neutron.conf
[DEFAULT]
auth_strategy = keystone
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
transport_url = rabbit://openstack:$RABBITPASS@$IPMANAGEMENT

[database]
connection = mysql+pymysql://neutron:$NEUTRONDBPASS@$IPMANAGEMENT/neutron

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

[nova]
auth_url = http://$IPMANAGEMENT:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVAPASS

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
_EOF_
chown root:neutron /etc/neutron/neutron.conf.d/500-neutron.conf

[ ! -f /etc/neutron/plugins/ml2/ml2_conf.ini.orig ] && cp -v /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.orig
cat << _EOF_ > /etc/neutron/plugins/ml2/ml2_conf.ini
[DEFAULT]

[ml2]
type_drivers = vxlan,flat
tenant_network_types = vxlan,flat
mechanism_drivers = openvswitch
extension_drivers = port_security,qos
path_mtu = 0

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000
vxlan_group = 224.0.0.1

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True
enable_ipset = True

_EOF_

[ ! -f /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig ] && cp -v /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.orig


cat << _EOF_ > /etc/neutron/plugins/ml2/openvswitch_agent.ini
[DEFAULT]

[agent]
tunnel_types = vxlan
vxlan_udp_port = 4789
l2_population = False
drop_flows_on_start = False

[ovs]
integration_bridge = br-int
tunnel_bridge = br-tun
local_ip = $IPMANAGEMENT
bridge_mappings = provider:br-ex

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

_EOF_


[ ! -f /etc/neutron/l3_agent.ini.orig ] && cp -v /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.orig
sed -i "s/#interface_driver = .*/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/" /etc/neutron/l3_agent.ini

[ ! -f /etc/neutron/dhcp_agent.ini.orig ] && cp -v /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.orig
sed -i "s/#interface_driver = .*/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/" /etc/neutron/dhcp_agent.ini
sed -i "s/#dhcp_driver = .*/dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq/" /etc/neutron/dhcp_agent.ini
sed -i "s/#enable_isolated_metadata = false/enable_isolated_metadata = true/" /etc/neutron/dhcp_agent.ini

[ ! -f /etc/neutron/metadata_agent.ini.orig ] && cp -v /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.orig
sed -i "s/#nova_metadata_host = .*/nova_metadata_host = $IPMANAGEMENT/" /etc/neutron/metadata_agent.ini
sed -i "s/#metadata_proxy_shared_secret =.*/metadata_proxy_shared_secret = $METADATAPASS/" /etc/neutron/metadata_agent.ini

_EOFNEW_

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
[ -f /etc/nova/nova.conf.d/500-nova.conf.orig ] && cp -v /etc/nova/nova.conf.d/500-nova.conf.orig /etc/nova/nova.conf.d/500-nova.conf
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
service_metadata_proxy = true
metadata_proxy_shared_secret = $METADATAPASS

_EOF_
chown root:nova  /etc/nova/nova.conf.d/500-nova.conf

echo 'NEUTRON_PLUGIN_CONF="/etc/neutron/plugins/ml2/ml2_conf.ini"' >> /etc/sysconfig/neutron
ln -s /etc/apparmor.d/usr.sbin.dnsmasq /etc/apparmor.d/disable/
# systemctl status apparmor
systemctl restart openstack-nova-api.service 
# Jika terdapat error database jalankan perintah ini.
# su -s /bin/sh -c "neutron-db-manage upgrade head" neutron
systemctl enable  openstack-neutron.service openstack-neutron-openvswitch-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service
systemctl restart openstack-neutron.service openstack-neutron-openvswitch-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service
sleep 5
systemctl restart openstack-neutron.service openstack-neutron-openvswitch-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service
sleep 5
systemctl restart openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service 
sleep 5
firewall-cmd --permanent --add-port=9696/tcp
firewall-cmd --reload

source keystonerc_admin
openstack extension list --network
openstack network agent list

_EOFNEWTEST_


echo -e "$red \n\n############## Completed running script Neutron ############## $color_off\n\n"