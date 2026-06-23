# valkey

A flexible distributed key-value database that is optimized for caching and other realtime workloads.

Next steps:
1. Configure helm charts in `components/valkey/charts.yaml`
2. Configure values for every release in `components/valkey/values`
3. Update your README.md
4. Update component to `defaults/environment/global.yaml` - `components` list

Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=valkey
