#!/bin/bash
source config.conf

echo -e "$red \n\n############## Starting running script Openstack Environment ############## $color_off\n\n"
cat /dev/zero | ssh-keygen -q -N ""
ssh-copy-id -i ~/.ssh/id_rsa.pub root@$IPMANAGEMENT

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
echo -e "$red \n###Configre Hostname### $color_off"
echo -e "$IPMANAGEMENT\t $HOSTNAME" >> /etc/hosts
echo -e "$red \n###Configre NTP### $color_off"
#### Configure NTP ####
zypper -n install --no-recommends chrony
[ -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf.orig /etc/chrony.conf
[ ! -f /etc/chrony.conf.orig ] && cp -v /etc/chrony.conf /etc/chrony.conf.orig
sed -i "s/^pool/#pool/" /etc/chrony.d/pool.conf
sed -i "s/^pool/#pool/" /etc/chrony.conf
echo "server 0.opensuse.pool.ntp.org iburst" >> /etc/chrony.conf
echo "server 1.opensuse.pool.ntp.org iburst" >> /etc/chrony.conf
echo "server 2.opensuse.pool.ntp.org iburst" >> /etc/chrony.conf
echo "server 3.opensuse.pool.ntp.org iburst" >> /etc/chrony.conf
echo "allow $NETMANAGEMENT" >> /etc/chrony.conf
systemctl enable chronyd.service
systemctl restart chronyd.service
chronyc sources

echo -e "$red \n###Install Openstack Client and adding repositories### $color_off"
#### Configure Repositories ####
[ ! -f /etc/zypp/repos.d/Stein.repo ] && zypper addrepo -f  obs://Cloud:OpenStack:Stein/openSUSE_Leap_15.1 Stein
zypper --gpg-auto-import-keys refresh && zypper -n dist-upgrade
zypper -n install --no-recommends python2-openstackclient openstack-utils
echo -e "$red \n###Install & Configure Mariadb### $color_off"
##### MariaDB Database Service #####
zypper -n install --no-recommends mariadb-client mariadb python2-PyMySQL
if [ ! -f /etc/my.cnf.d/openstack.cnf ]
  then
cat << _EOF_ > /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = $IPMANAGEMENT
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
_EOF_
    systemctl enable mysql.service
    systemctl restart mysql.service
    mysqladmin --user=root password "$DBPASSWORD"
    mysql -uroot -p"$DBPASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -uroot -p"$DBPASSWORD" -e "DELETE FROM mysql.user WHERE User='';"
    mysql -uroot -p"$DBPASSWORD" -e "DROP DATABASE test;"
	mysql -uroot -p"$DBPASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    mysql -uroot -p"$DBPASSWORD" -e "FLUSH PRIVILEGES;"
fi

echo -e "$red \n###Configre & Installing RabbitMQ###$color_off"
#### Configure & install RabbitMQ Service ####
zypper -n install --no-recommends rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl restart rabbitmq-server.service

_EOFNEWTEST_

ssh root@$IPMANAGEMENT rabbitmqctl add_user openstack $RABBITPASS
ssh root@$IPMANAGEMENT rabbitmqctl set_permissions openstack \".*\" \".*\" \".*\"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_
echo -e "$red \n\tConfigre Memcached.. $color_off"
#### Configure Memcached Service ####
zypper -n install --no-recommends memcached python2-python-memcached
sed -i "s/MEMCACHED_PARAMS=\"-l 127.0.0.1\"/MEMCACHED_PARAMS=\"-l $IPMANAGEMENT\"/" /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl restart memcached.service

echo -e "$red \n\tConfigre ETCD.. $color_off"
groupadd --system etcd
useradd --home-dir "/var/lib/etcd" --system --shell /bin/false -g etcd etcd

if [ ! -f /etc/etcd/etcd.conf.yml ]
  then
mkdir -p /etc/etcd
chown etcd:etcd /etc/etcd
mkdir -p /var/lib/etcd
chown etcd:etcd /var/lib/etcd
rm -rf /tmp/etcd && mkdir -p /tmp/etcd
[ ! -f /tmp/etcd-v3.2.7-linux-amd64.tar.gz ] && wget https://github.com/coreos/etcd/releases/download/v3.2.7/etcd-v3.2.7-linux-amd64.tar.gz -O /tmp/etcd-v3.2.7-linux-amd64.tar.gz
tar xzvf /tmp/etcd-v3.2.7-linux-amd64.tar.gz -C /tmp/etcd --strip-components=1
cp /tmp/etcd/etcd /usr/bin/etcd
cp /tmp/etcd/etcdctl /usr/bin/etcdctl
cat << _EOF_ > /etc/etcd/etcd.conf.yml
name: $HOSTNAME
data-dir: /var/lib/etcd
initial-cluster-state: 'new'
initial-cluster-token: 'etcd-cluster-01'
initial-cluster: $HOSTNAME=http://$IPMANAGEMENT:2380
initial-advertise-peer-urls: http://$IPMANAGEMENT:2380
advertise-client-urls: http://$IPMANAGEMENT:2379
listen-peer-urls: http://0.0.0.0:2380
listen-client-urls: http://$IPMANAGEMENT:2379
_EOF_

cat << _EOF_ > /usr/lib/systemd/system/etcd.service
[Unit]
After=network.target
Description=etcd - highly-available key value store

[Service]
LimitNOFILE=65536
Restart=on-failure
Type=notify
ExecStart=/usr/bin/etcd --config-file /etc/etcd/etcd.conf.yml
User=etcd

[Install]
WantedBy=multi-user.target
_EOF_

systemctl daemon-reload
systemctl enable etcd
systemctl restart etcd
fi
systemctl stop apparmor
systemctl disable apparmor
sleep 3
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --permanent --add-port=5672/tcp
firewall-cmd --permanent --add-port=11211/tcp
firewall-cmd --reload

_EOFNEWTEST_

echo -e "$red \n\n############## Completed running script Openstack Environment ############## $color_off\n\n"
