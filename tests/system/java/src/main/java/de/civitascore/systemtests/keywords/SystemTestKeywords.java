package de.civitascore.systemtests.keywords;

import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.KeycloakClient;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

@RobotKeywords
public class SystemTestKeywords {

  private final SystemTestState state = TestContext.state();
  private final KeycloakClient keycloakClient = TestContext.keycloakClient();
  private final DataSetKeywords dataSetKeywords = new DataSetKeywords();
  private final DataSourceKeywords dataSourceKeywords = new DataSourceKeywords();
  private final DataStructureKeywords dataStructureKeywords = new DataStructureKeywords();
  private final DatapoolKeywords datapoolKeywords = new DatapoolKeywords();

  @RobotKeyword("Initialize System Test Run")
  @ArgumentNames({"suffix=", "openDataAccess=false"})
  public String initializeSystemTestRun(String suffix, String openDataAccess) {
    state.reset();
    state.runSuffix = KeywordUtils.sanitizeSuffix(KeywordUtils.firstNonBlank(suffix, KeywordUtils.generatedSuffix()));
    state.openDataAccess = KeywordUtils.parseBoolean(openDataAccess);
    state.accessToken = keycloakClient.getAccessToken();
    state.dataStructureName = "Sensor Data Structure " + state.runSuffix;
    state.dataStructureVersionName = "Sensor Data Structure Version " + state.runSuffix;
    state.dataSourceName = "Saga MQTT DataSource " + state.runSuffix;
    state.dataSetName = "Saga DataSet " + state.runSuffix;
    state.pipelineName = "Saga Pipeline " + state.runSuffix;
    state.pipelineDescription = "Robot/Java system test proof of concept";
    state.geoPipelineName = "Saga Geo Pipeline " + state.runSuffix;
    state.geoPipelineDescription = "Robot/Java geo system test proof of concept";
    state.geoDataSinkTableName = "geo_data_" + state.runSuffix.replace('-', '_');
    state.geoApiName = "WFS/WMS API";
    state.geoApiSlug = "ows";
    state.geoApiDescription = "Geo API for the system test proof of concept";
    state.geoLayerName = "geo_layer_" + state.runSuffix.replace('-', '_');
    state.geoLayerTitle = "Geo Layer " + state.runSuffix;
    state.geoLayerDescription = "Geo layer for the system test proof of concept";
    state.geoLayerAttribute = "value";
    state.geoLayerGeometryColumnRef = "value";
    state.geoLayerCrs = "EPSG:4326";
    state.dataSourceClientId = "civitas-saga-demo-" + state.runSuffix;
    state.namedApiSlug = "things";
    state.dataPoolName = "Test DataPool " + state.runSuffix;
    state.modelAtlasUri = "http://civitas.org/model/SagaSensorModel/1.0.0";
    state.modelName = "SagaSensorModel";
    state.expectedGatewayThingName = "Test Sensor";
    state.expectedGatewayThingDescription = "test";
    return state.runSuffix;
  }

  @RobotKeyword("Cleanup System Test Run")
  public void cleanupSystemTestRun() {
    safe("dataset", () -> dataSetKeywords.cleanupDataSet());
    safe("datasource", () -> dataSourceKeywords.cleanupDataSource());
    safe("datastructure", () -> dataStructureKeywords.cleanupDataStructure());
    safe("datapool", () -> datapoolKeywords.cleanupDataPool());
  }

  private void safe(String label, Runnable action) {
    try {
      action.run();
    } catch (Exception ex) {
      System.err.println("[WARN] Cleanup step failed for " + label + ": " + ex.getMessage());
    }
  }

}
