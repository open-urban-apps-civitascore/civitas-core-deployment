# AuthZ

general-purpose policy engine

Next steps:
1. Configure helm charts in `components/authz/charts.yaml`
2. Configure values for every release in `components/authz/values`
3. Update your README.md
4. Update component to `defaults/environment/global.yaml` - `components` list

Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=authz
