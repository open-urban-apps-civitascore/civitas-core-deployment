# Redpanda Connect

Data streaming service for building scalable, high-performance data pipelines in the platform

Next steps:
1. Configure helm charts in `components/redpanda-connect/charts.yaml`
2. Configure values for every release in `components/redpanda-connect/values`
3. Update your README.md
4. Update component to `defaults/environment/global.yaml` - `components` list

Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=redpanda-connect
