#!/bin/bash

source keystonerc_admin

###Add Flavor###
openstack flavor create --public m1.nano --ram 64 --id auto --disk 1 --vcpus 1
openstack flavor create --public m1.tiny --ram 512 --id auto --disk 1 --vcpus 1
openstack flavor create --public m1.xsmall --ram 1024 --id auto --disk 10 --vcpus 1
openstack flavor create --public m1.small --ram 2048 --id auto --disk 15 --vcpus 1
openstack flavor create --public m1.medium --ram 4096 --id auto --disk 20 --vcpus 2
openstack flavor create --public m1.large --ram 8192 --id auto --disk 80 --vcpus 4
openstack flavor create --public m1.xlarge --ram 16384 --id auto --disk 160 --vcpus 8
openstack flavor list

###Add User and project###
USERNAME='rizqi alfian'

for USER in $USERNAME
do
    openstack project create $USER --domain default
    openstack user create --project $USER --password $USER $USER
done

