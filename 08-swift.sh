#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Swift ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEW_
source keystonerc_admin
openstack user list | grep swift > /dev/null 2>&1 && echo -e "$red \n ## swift user already exists ## $color_off" || openstack user create --domain default --password $SWIFTPASS swift
openstack role add --project service --user swift admin
openstack service list | grep swift > /dev/null 2>&1 && echo -e "$red \n ## swift service already exists ## $color_off" || openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint list | grep public | grep swift > /dev/null 2>&1 &&  echo -e "$red \n ## swift public endpoint already exists ## $color_off" ||  openstack endpoint create --region RegionOne object-store public http://$IPMANAGEMENT:8080/v1/AUTH_%\(project_id\)s
openstack endpoint list | grep internal | grep swift > /dev/null 2>&1 && echo -e "$red \n ## swift internal endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne object-store internal http://$IPMANAGEMENT:8080/v1/AUTH_%\(project_id\)s
openstack endpoint list | grep admin | grep swift > /dev/null 2>&1 &&  echo -e "$red \n ## swift admin endpoint already exists ## $color_off" || openstack endpoint create --region RegionOne object-store admin http://$IPMANAGEMENT:8080/v1
_EOFNEW_

ssh root@$IPMANAGEMENT << _EOFNEW_
zypper -n install --no-recommends openstack-swift-proxy python2-swiftclient python2-swiftclient python2-keystoneclient python2-xml memcached openstack-swift-account openstack-swift-container openstack-swift-object xfsprogs rsync
[ ! -f /etc/swift/proxy-server.conf.orig ] && cp -v /etc/swift/proxy-server.conf /etc/swift/proxy-server.conf.orig
sed -i "s|# swift_dir = /etc/swift|swift_dir = /etc/swift|" /etc/swift/proxy-server.conf
sed -i "s/^pipeline = .*/pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server/" /etc/swift/proxy-server.conf
sed -i "s/# account_autocreate = false/account_autocreate = True/" /etc/swift/proxy-server.conf
sed -i "s|# \[filter:keystoneauth\]|\[filter:keystoneauth\]|" /etc/swift/proxy-server.conf
sed -i "s|# use = egg:swift#keystoneauth|use = egg:swift#keystoneauth|" /etc/swift/proxy-server.conf
sed -i "s/# operator_roles = .*/operator_roles = admin,user/" /etc/swift/proxy-server.conf
sed -i "s|# \[filter:authtoken\]|\[filter:authtoken\]|" /etc/swift/proxy-server.conf
sed -i "s/# paste.filter_factory = .*/paste.filter_factory = keystonemiddleware.auth_token:filter_factory/" /etc/swift/proxy-server.conf
sed -i "s|# www_authenticate_uri = .*|www_authenticate_uri = http://$IPMANAGEMENT:5000|" /etc/swift/proxy-server.conf
sed -i "s|# auth_url = .*|auth_url = http://$IPMANAGEMENT:5000|" /etc/swift/proxy-server.conf
sed -i "s/# auth_plugin = password/auth_type = password/" /etc/swift/proxy-server.conf
sed -i "385 i memcached_servers = $IPMANAGEMENT:11211" /etc/swift/proxy-server.conf
sed -i "s/# project_domain_id = default/project_domain_id = default/" /etc/swift/proxy-server.conf
sed -i "s/# user_domain_id = default/user_domain_id = default/" /etc/swift/proxy-server.conf
sed -i "s/# project_name = service/project_name = service/" /etc/swift/proxy-server.conf
sed -i "s/# username = swift/username = swift/" /etc/swift/proxy-server.conf
sed -i "s/# password = password/password = $SWIFTPASS/" /etc/swift/proxy-server.conf
sed -i "s/# delay_auth_decision = False/delay_auth_decision = True/" /etc/swift/proxy-server.conf
sed -i "s/# memcache_servers = 127.0.0.1:11211/memcache_servers = $IPMANAGEMENT:11211/" /etc/swift/proxy-server.conf

_EOFNEW_

for DEVSWIFT in $SWIFTDEV
do
ssh root@$IPMANAGEMENT  << _EOFNEW_
	blkid /dev/$DEVSWIFT | grep xfs > /dev/null 2>&1 && echo "/dev/$DEVSWIFT already formatted as XFS" || mkfs.xfs -f /dev/$DEVSWIFT
	
	mkdir -p /srv/node/$DEVSWIFT
	
	grep /dev/$DEVSWIFT /etc/fstab > /dev/null 2>&1 && echo "/dev/$DEVSWIFT already in /etc/fstab" || echo "/dev/$DEVSWIFT /srv/node/$DEVSWIFT xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab

	mount /srv/node/$DEVSWIFT
_EOFNEW_
done

ssh root@$IPMANAGEMENT  << _EOFNEW_
[ ! -f /etc/rsyncd.conf.orig ] && cp -v /etc/rsyncd.conf /etc/rsyncd.conf.orig
cat << _EOF_ > /etc/rsyncd.conf
read only = true
use chroot = true
transfer logging = true
log format = %h %o %f %l %b
hosts allow = trusted.hosts
slp refresh = 300
use slp = false

uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $IPMANAGEMENT

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock
_EOF_

systemctl enable rsyncd.service
systemctl restart rsyncd.service

[ ! -f /etc/swift/account-server.conf.orig ] && cp -v /etc/swift/account-server.conf /etc/swift/account-server.conf.orig
cat << _EOF_ > /etc/swift/account-server.conf
[DEFAULT]
bind_ip = $IPMANAGEMENT
bind_port = 6202
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon account-server

[app:account-server]
use = egg:swift#account

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[filter:xprofile]
use = egg:swift#xprofile

[account-replicator]

[account-auditor]

[account-reaper]

_EOF_

[ ! -f /etc/swift/container-server.conf.orig ] && cp -v /etc/swift/container-server.conf /etc/swift/container-server.conf.orig
cat << _EOF_ > /etc/swift/container-server.conf
[DEFAULT]
bind_ip = $IPMANAGEMENT
bind_port = 6201
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon container-server

[app:container-server]
use = egg:swift#container

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[filter:xprofile]
use = egg:swift#xprofile

[container-replicator]

[container-auditor]

[container-updater]

_EOF_

[ ! -f /etc/swift/object-server.conf.orig ] && cp -v /etc/swift/object-server.conf /etc/swift/object-server.conf.orig
cat << _EOF_ > /etc/swift/object-server.conf
[DEFAULT]
bind_ip = $IPMANAGEMENT
bind_port = 6200
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon object-server

[app:object-server]
use = egg:swift#object

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
recon_lock_path = /var/lock

[filter:xprofile]
use = egg:swift#xprofile

[object-replicator]

[object-auditor]

[object-updater]

_EOF_

chown -R swift:swift /srv/node
_EOFNEW_

ssh root@$IPMANAGEMENT [ -f /etc/swift/account.builder ] && echo "account.builder file already exist" || " cd /etc/swift; swift-ring-builder account.builder create 10 $REPLIKASI 1"
for DEVSWIFT in $SWIFTDEV
do 
ssh root@$IPMANAGEMENT "cd /etc/swift ; swift-ring-builder account.builder add --region 1 --zone 1 --ip $IPMANAGEMENT --port 6202 --device $DEVSWIFT --weight 100"
done
ssh root@$IPMANAGEMENT " cd /etc/swift ; swift-ring-builder account.builder"
ssh root@$IPMANAGEMENT " cd /etc/swift ; swift-ring-builder account.builder rebalance"
ssh root@$IPMANAGEMENT [ -f /etc/swift/container.builder ] && echo "container.builder file already exist" || "cd /etc/swift; swift-ring-builder container.builder create 10 $REPLIKASI 1" 
for DEVSWIFT in $SWIFTDEV
do
ssh root@$IPMANAGEMENT  "cd /etc/swift ; swift-ring-builder container.builder add --region 1 --zone 1 --ip $IPMANAGEMENT --port 6201 --device $DEVSWIFT --weight 100"
done
ssh root@$IPMANAGEMENT " cd /etc/swift ; swift-ring-builder container.builder"
ssh root@$IPMANAGEMENT " cd /etc/swift ; swift-ring-builder container.builder rebalance"
ssh root@$IPMANAGEMENT [ -f /etc/swift/object.builder ] && echo "object.builder file already exist" || "cd /etc/swift ; swift-ring-builder object.builder create 10 2 1"
for DEVSWIFT in $SWIFTDEV
do
ssh root@$IPMANAGEMENT "cd /etc/swift ; swift-ring-builder object.builder add --region 1 --zone 1 --ip $IPMANAGEMENT --port 6200 --device $DEVSWIFT --weight 100"
done
ssh root@$IPMANAGEMENT "cd /etc/swift ; swift-ring-builder object.builder"
ssh root@$IPMANAGEMENT "cd /etc/swift ; swift-ring-builder object.builder rebalance"

ssh root@$IPMANAGEMENT << _EOFNEW_
[ ! -f /etc/swift/swift.conf.orig ] && cp -v /etc/swift/swift.conf /etc/swift/swift.conf.orig
cat << _EOF_ > /etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = $SWIFT_HASH_SUFFIX
swift_hash_path_prefix = $SWIFT_HASH_PREFIX

[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange
_EOF_

chown -R root:swift /etc/swift

systemctl enable openstack-swift-proxy.service memcached.service openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl restart openstack-swift-proxy.service memcached.service openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
sleep 5
firewall-cmd --permanent --add-port 8080/tcp
firewall-cmd --permanent --add-port 6000-6002/tcp
firewall-cmd --reload
firewall-cmd --list-all
source keystonerc_admin
swift stat

_EOFNEW_

echo -e "$red \n\n############## Completed running script Openstack Swift ############## $color_off\n\n"