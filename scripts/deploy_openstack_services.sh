#!/usr/bin/env bash

export INTERACTIVE=false

osism-kolla deploy keystone
osism-kolla deploy horizon
osism-kolla deploy glance
osism-kolla deploy cinder
osism-kolla deploy neutron
osism-kolla deploy nova
osism-kolla deploy heat