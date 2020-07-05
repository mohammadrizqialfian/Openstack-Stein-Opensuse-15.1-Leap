#!/bin/bash

source config.conf

echo -e "$red \n\n############## Starting running script Openstack Horizon ############## $color_off\n\n"

ssh root@$IPMANAGEMENT << _EOFNEW_
zypper -n install --no-recommends openstack-dashboard
cp /etc/apache2/conf.d/openstack-dashboard.conf.sample /etc/apache2/conf.d/openstack-dashboard.conf
a2enmod rewrite
[ -f /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py.orig ] && cp -v /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py.orig /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
[ ! -f /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py.orig ] && cp -v /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py.orig
sed -i "s/OPENSTACK_HOST = .*/OPENSTACK_HOST = \"$HOSTNAME\"/" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "s/OPENSTACK_KEYSTONE_DEFAULT_ROLE = .*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "s/#ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "s/#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"/" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "166 i SESSION_ENGINE = \'django.contrib.sessions.backends.cache\'" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "166 a CACHES = \{" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "167 a \    \'default\': \{" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "168 a \        \'BACKEND\': \'django.core.cache.backends.memcached.MemcachedCache\'," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "169 a \        \'LOCATION\': \'$IPMANAGEMENT:11211\'," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "170 a \    \}," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "171 a \}" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "s/#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = .*/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True/" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "66 i OPENSTACK_API_VERSIONS = /{" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "66 a \    \'identity\' : 3," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "67 a \    \'image\' : 2," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "68 a \    \'volume\' : 3," /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i "69 a \}" /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
sed -i 's|TIME_ZONE = .*|TIME_ZONE = "Asia/Jakarta"|' /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
systemctl restart apache2.service memcached.service
sleep 5
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

_EOFNEW_

echo -e "$red \n\n############## Completed running script Openstack Horizon ############## $color_off\n\n"