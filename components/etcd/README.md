# Etcd

Etcd storage for some components.

Currently used for components which would use a bitnami etcd chart.

Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=etcd
