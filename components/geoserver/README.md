# Geoserver

GeoServer is an open-source server for sharing, editing, and managing geospatial data using standardized web services like WMS, WFS, and WCS.

Next steps:
1. Configure helm charts in `components/geoserver/charts.yaml`
2. Configure values for every release in `components/geoserver/values`
3. Update your README.md
4. Update component to `defaults/environment/global.yaml` - `components` list

Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=geoserver
