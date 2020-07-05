#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Keystone ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEWTEST_

mysql -u root -p$DBPASSWORD -e "SHOW DATABASES;" | grep keystone > /dev/null 2>&1 && echo -e "$red \n## keystone database already exists ## $color_off" || mysql -u root -p$DBPASSWORD -e "CREATE DATABASE keystone; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONEDBPASS'; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONEDBPASS';"

echo -e "$red \n\tInstall & Configure Keystone.. $color_off"
zypper -n install --no-recommends python2-pyasn1
zypper -n install --no-recommends openstack-keystone apache2 apache2-mod_wsgi
[ ! -f /etc/keystone/keystone.conf.orig ] && cp -v /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig
cat << _EOF_ > /etc/keystone/keystone.conf.d/010-keystone.conf
[DEFAULT]
log_dir=/var/log/keystone

[database]
connection = mysql+pymysql://keystone:$KEYSTONEDBPASS@$IPMANAGEMENT/keystone

[token]
provider = fernet
_EOF_

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password $ADMINLOG --bootstrap-admin-url http://$IPMANAGEMENT:5000/v3/ --bootstrap-internal-url http://$IPMANAGEMENT:5000/v3/ --bootstrap-public-url http://$IPMANAGEMENT:5000/v3/ --bootstrap-region-id RegionOne
[ ! -f /etc/sysconfig/apache2.orig ] && cp -v /etc/sysconfig/apache2 /etc/sysconfig/apache2.orig
sed -i "s/APACHE_SERVERNAME=.*/APACHE_SERVERNAME=\"$HOSTNAME\"/" /etc/sysconfig/apache2

cat << _EOF_ > /etc/apache2/conf.d/wsgi-keystone.conf
Listen 5000

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>
_EOF_
echo "LoadModule wsgi_module /usr/lib64/apache2/mod_wsgi.so" >> /etc/apache2/loadmodule.conf
chown -R keystone:keystone /etc/keystone
systemctl enable apache2.service
systemctl restart apache2.service
firewall-cmd --permanent --add-port=5000/tcp
firewall-cmd --reload

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

source keystonerc_admin
openstack project list | grep service > /dev/null 2>&1 && echo -e "$red \n## service project already exist ##$color_off" || openstack project create --domain default --description "Service Project" service
openstack role list | grep user > /dev/null 2>&1 && echo -e "$red\n ### User role already exist##$color_off"openstack role create user

_EOFNEWTEST_

echo -e "$red \n\n############## Completed running script Openstack Keystone ############## $color_off\n\n"
