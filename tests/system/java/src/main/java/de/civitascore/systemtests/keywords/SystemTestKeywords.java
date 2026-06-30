package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.ResourceSupplier;
import de.civitascore.systemtests.SystemTestConfig;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.KeycloakClient;
import de.civitascore.systemtests.client.PortalBackendClient;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

@RobotKeywords
public class SystemTestKeywords {

  private final SystemTestConfig config = TestContext.config();
  private final ObjectMapper mapper = TestContext.mapper();
  private final HttpClient httpClient = TestContext.httpClient();
  private final SystemTestState state = TestContext.state();
  private final KeycloakClient keycloakClient = TestContext.keycloakClient();
  private final PortalBackendClient portalClient = TestContext.portalClient();
  private final DatapoolKeywords datapoolKeywords = new DatapoolKeywords();

  @RobotKeyword("Initialize System Test Run")
  @ArgumentNames({"suffix=", "openDataAccess=false"})
  public String initializeSystemTestRun(String suffix, String openDataAccess) {
    state.reset();
    state.runSuffix = sanitizeSuffix(firstNonBlank(suffix, generatedSuffix()));
    state.openDataAccess = parseBoolean(openDataAccess);
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
    safe("dataset", () -> cleanupDataSet());
    safe("datasource", () -> cleanupDataSource());
    safe("datastructure", () -> cleanupDataStructure());
    safe("datapool", () -> datapoolKeywords.cleanupDataPool());
  }

  @RobotKeyword("Get Generated Data Structure Name")
  public String getGeneratedDataStructureName() {
    ensureInitialized();
    return state.dataStructureName;
  }

  @RobotKeyword("Get Generated Data Structure Version Name")
  public String getGeneratedDataStructureVersionName() {
    ensureInitialized();
    return state.dataStructureVersionName;
  }

  @RobotKeyword("Get Generated Data Source Name")
  public String getGeneratedDataSourceName() {
    ensureInitialized();
    return state.dataSourceName;
  }

  @RobotKeyword("Get Generated Data Set Name")
  public String getGeneratedDataSetName() {
    ensureInitialized();
    return state.dataSetName;
  }

  @RobotKeyword("Get Generated Pipeline Name")
  public String getGeneratedPipelineName() {
    ensureInitialized();
    return state.pipelineName;
  }

  @RobotKeyword("Get Generated Geo Pipeline Name")
  public String getGeneratedGeoPipelineName() {
    ensureInitialized();
    return state.geoPipelineName;
  }

  @RobotKeyword("Get Generated Geo Data Sink Table Name")
  public String getGeneratedGeoDataSinkTableName() {
    ensureInitialized();
    return state.geoDataSinkTableName;
  }

  @RobotKeyword("Get Generated OWS API Name")
  public String getGeneratedOwsApiName() {
    ensureInitialized();
    return state.geoApiName;
  }

  @RobotKeyword("Get Generated OWS API Slug")
  public String getGeneratedOwsApiSlug() {
    ensureInitialized();
    return state.geoApiSlug;
  }

  @RobotKeyword("Get Generated Geo Layer Name")
  public String getGeneratedGeoLayerName() {
    ensureInitialized();
    return state.geoLayerName;
  }

  @RobotKeyword("Get Generated Geo Layer Title")
  public String getGeneratedGeoLayerTitle() {
    ensureInitialized();
    return state.geoLayerTitle;
  }

  @RobotKeyword("Get Generated Geo Layer Description")
  public String getGeneratedGeoLayerDescription() {
    ensureInitialized();
    return state.geoLayerDescription;
  }

  @RobotKeyword("Get Generated Geo Layer Attribute")
  public String getGeneratedGeoLayerAttribute() {
    ensureInitialized();
    return state.geoLayerAttribute;
  }

  @RobotKeyword("Get Generated Geo Layer Geometry Column Ref")
  public String getGeneratedGeoLayerGeometryColumnRef() {
    ensureInitialized();
    return state.geoLayerGeometryColumnRef;
  }

  @RobotKeyword("Get Generated Geo Layer CRS")
  public String getGeneratedGeoLayerCrs() {
    ensureInitialized();
    return state.geoLayerCrs;
  }

  @RobotKeyword("Get Named API Slug")
  public String getNamedApiSlug() {
    ensureInitialized();
    return state.namedApiSlug;
  }

  @RobotKeyword("Get Expected Gateway Thing Name")
  public String getExpectedGatewayThingName() {
    ensureInitialized();
    return state.expectedGatewayThingName;
  }

  @RobotKeyword("Get Expected Gateway Thing Description")
  public String getExpectedGatewayThingDescription() {
    ensureInitialized();
    return state.expectedGatewayThingDescription;
  }

  @RobotKeyword("Create Data Structure")
  public String createDataStructure() {
    ensureInitialized();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", state.dataStructureName);
    body.put("description", "Data structure for the dataset saga system test");
    body.put("createdFromDataSource", false);
    body.set("dataStructureVersionIds", mapper.createArrayNode());
    body.set("assignments", mapper.createArrayNode());

    JsonNode result = portalClient.postJson("/datastructures", body, state.accessToken, 201).json();
    state.dataStructureId = requiredText(result, "id", "dataStructure");
    validateDataStructurePayload(result, "DRAFT", false);
    return state.dataStructureId;
  }

  @RobotKeyword("Verify Data Structure Snapshot")
  @ArgumentNames({"expectedStatus=DRAFT", "expectVersionReference=false"})
  public void verifyDataStructureSnapshot(String expectedStatus, String expectVersionReference) {
    ensureDataStructureId();
    JsonNode dataStructure = portalClient
        .getJson("/datastructures/" + state.dataStructureId, state.accessToken, 200)
        .json();
    validateDataStructurePayload(dataStructure, expectedStatus, parseBoolean(expectVersionReference));
  }

  @RobotKeyword("Create Data Structure Version")
  public String createDataStructureVersion() {
    ensureDataStructureId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataStructureVersionSource", "OWN");
    body.put("version", "1.0.0");
    body.put("description", "Initial release for the system test proof of concept");
    body.put("modelAtlasUri", state.modelAtlasUri);
    body.put("modelName", state.modelName);
    body.put("model", readResource("/models/simple-model.xmi"));
    body.set("styles", mapper.createObjectNode());

    JsonNode result = portalClient.postJson(
        "/datastructures/" + state.dataStructureId + "/versions", body, state.accessToken, 201).json();
    state.dataStructureVersionId = requiredText(result, "id", "dataStructureVersion");
    validateDataStructureVersionPayload(result);
    return state.dataStructureVersionId;
  }

  @RobotKeyword("Verify Data Structure Version Snapshot")
  public void verifyDataStructureVersionSnapshot() {
    ensureDataStructureVersionId();
    JsonNode version = portalClient
        .getJson(
            "/datastructures/" + state.dataStructureId + "/versions/" + state.dataStructureVersionId,
            state.accessToken,
            200)
        .json();
    validateDataStructureVersionPayload(version);
  }

  @RobotKeyword("Release Data Structure Version")
  public void releaseDataStructureVersion() {
    ensureDataStructureVersionId();
    portalClient.postVoid(
        "/datastructures/" + state.dataStructureId + "/versions/" + state.dataStructureVersionId + "/release",
        state.accessToken,
        200);
  }

  @RobotKeyword("Release Data Structure")
  public void releaseDataStructure() {
    ensureDataStructureId();
    portalClient.postVoid("/datastructures/" + state.dataStructureId + "/release", state.accessToken, 200);
  }

  @RobotKeyword("Create Data Source")
  public String createDataSource() {
    ensureInitialized();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", state.dataSourceName);
    body.put("description", "MQTT datasource for the system test proof of concept");
    body.put("connectorType", "MQTT");

    ObjectNode configuration = body.putObject("configuration");
    ArrayNode urls = configuration.putArray("urls");
    urls.add("tcp://broker.hivemq.com:1883");
    ArrayNode topics = configuration.putArray("topics");
    topics.add("+/civitas+/civitas/core/energy/meter/+/taf10");
    configuration.put("client_id", state.dataSourceClientId);
    configuration.put("qos", 1);
    configuration.put("connect_timeout", "5s");
    configuration.put("keepalive", "30s");
    ObjectNode tls = configuration.putObject("tls");
    tls.put("enabled", false);

    body.putNull("dataStructureVersionId");
    body.set("assignments", mapper.createArrayNode());

    JsonNode result = portalClient.postJson("/datasources", body, state.accessToken, 201).json();
    state.dataSourceId = requiredText(result, "id", "dataSource");
    validateDataSourcePayload(result, "DRAFT", false);
    return state.dataSourceId;
  }

  @RobotKeyword("Verify Data Source Snapshot")
  @ArgumentNames({"expectedStatus=DRAFT", "expectDataStructureVersion=false"})
  public void verifyDataSourceSnapshot(String expectedStatus, String expectDataStructureVersion) {
    ensureDataSourceId();
    JsonNode dataSource = portalClient.getJson("/datasources/" + state.dataSourceId, state.accessToken, 200).json();
    validateDataSourcePayload(dataSource, expectedStatus, parseBoolean(expectDataStructureVersion));
  }

  @RobotKeyword("Patch Data Source With Data Structure Version")
  public void patchDataSourceWithDataStructureVersion() {
    ensureDataSourceId();
    ensureDataStructureVersionId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataStructureVersionId", state.dataStructureVersionId);
    ApiResponse response = portalClient.patchJson("/datasources/" + state.dataSourceId, body, state.accessToken, 200);
    JsonNode result = responseJsonOrFetch(
        response,
        () -> portalClient.getJson("/datasources/" + state.dataSourceId, state.accessToken, 200).json(),
        "Patch datasource with data structure version");
    validateDataSourcePayload(result, "DRAFT", true);
  }

  @RobotKeyword("Release Data Source")
  public void releaseDataSource() {
    ensureDataSourceId();
    portalClient.postVoid("/datasources/" + state.dataSourceId + "/release", state.accessToken, 200);
  }

  @RobotKeyword("Create Data Set")
  public String createDataSet() {
    ensureInitialized();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", state.dataSetName);
    body.put("description", "Dataset for the system test proof of concept");
    body.put("openDataAccess", state.openDataAccess);

    ArrayNode namedApis = body.putArray("namedApis");
    ObjectNode namedApi = namedApis.addObject();
    namedApi.put("name", "Things");
    namedApi.put("slug", state.namedApiSlug);
    namedApi.put("standard", "STA");
    namedApi.put("version", "1.1");

    JsonNode result = portalClient.postJson("/datasets", body, state.accessToken, 201).json();
    state.dataSetId = requiredText(result, "id", "dataSet");
    validateDataSetPayload(result, "DRAFT", false);
    return state.dataSetId;
  }

  @RobotKeyword("Verify Data Set Snapshot")
  @ArgumentNames({"expectedStatus=DRAFT", "expectPublicRoutes=false"})
  public void verifyDataSetSnapshot(String expectedStatus, String expectPublicRoutes) {
    ensureDataSetId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    validateDataSetPayload(dataset, expectedStatus, parseBoolean(expectPublicRoutes));
  }

  @RobotKeyword("Create Pipeline")
  public String createPipeline() {
    ensureDataSetId();
    ensureDataSourceId();
    ObjectNode body = buildPipelinePayload(state.pipelineName, state.pipelineDescription);

    JsonNode result = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/pipelines", body, state.accessToken, 201).json();
    state.pipelineId = requiredText(result, "id", "pipeline");
    validatePipelinePayload(result);
    return state.pipelineId;
  }

  @RobotKeyword("Create Geo Pipeline")
  public String createGeoPipeline() {
    ensureDataSetId();
    ensureDataSourceId();
    ensureDataStructureVersionId();
    ObjectNode body = buildPipelinePayload(state.geoPipelineName, state.geoPipelineDescription);
    ArrayNode dataSinks = body.putArray("dataSinks");
    ObjectNode sink = dataSinks.addObject();
    sink.put("dataSinkType", "POSTGIS");
    ObjectNode configuration = sink.putObject("configuration");
    configuration.put("tableName", state.geoDataSinkTableName);
    configuration.put("dataStructureVersionId", state.dataStructureVersionId);

    JsonNode result = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/pipelines", body, state.accessToken, 201).json();
    state.geoPipelineId = requiredText(result, "id", "geoPipeline");
    validateGeoPipelinePayload(result);

    JsonNode dataSinksResult = result.path("dataSinks");
    assertTrue(dataSinksResult.isArray() && !dataSinksResult.isEmpty(), "geo pipeline must return a POSTGIS sink");
    JsonNode firstSink = dataSinksResult.get(0);
    state.geoDataSinkId = requiredText(firstSink, "id", "geoPipeline.dataSinks[0].id");
    return state.geoPipelineId;
  }

  @RobotKeyword("Verify Pipeline Snapshot")
  public void verifyPipelineSnapshot() {
    ensureDataSetId();
    if (state.pipelineId == null) {
      throw new IllegalStateException("Pipeline has not been created yet");
    }
    JsonNode pipeline = portalClient
        .getJson("/datasets/" + state.dataSetId + "/pipelines/" + state.pipelineId, state.accessToken, 200)
        .json();
    validatePipelinePayload(pipeline);
  }

  @RobotKeyword("Verify Geo Pipeline Snapshot")
  public void verifyGeoPipelineSnapshot() {
    ensureDataSetId();
    if (state.geoPipelineId == null) {
      throw new IllegalStateException("Geo pipeline has not been created yet");
    }
    JsonNode pipeline = portalClient
        .getJson("/datasets/" + state.dataSetId + "/pipelines/" + state.geoPipelineId, state.accessToken, 200)
        .json();
    validateGeoPipelinePayload(pipeline);
  }

  @RobotKeyword("Create OWS API")
  public void createOwsApi() {
    ensureDataSetId();
    ObjectNode body = mapper.createObjectNode();
    ArrayNode namedApis = body.putArray("namedApis");

    ObjectNode things = namedApis.addObject();
    things.put("name", "Things");
    things.put("slug", state.namedApiSlug);
    things.put("standard", "STA");
    things.put("version", "1.1");

    ObjectNode ows = namedApis.addObject();
    ows.put("name", state.geoApiName);
    ows.put("slug", state.geoApiSlug);
    ows.put("standard", "OWS");
    ows.put("description", state.geoApiDescription);

    JsonNode result = portalClient.patchJson("/datasets/" + state.dataSetId, body, state.accessToken, 200).json();
    validateDataSetPayload(result, "DRAFT", false);
    validateNamedApiPresence(result, state.geoApiSlug, state.geoApiName, "OWS", state.geoApiDescription);
  }

  @RobotKeyword("Verify OWS API Snapshot")
  public void verifyOwsApiSnapshot() {
    ensureDataSetId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    validateNamedApiPresence(dataset, state.geoApiSlug, state.geoApiName, "OWS", state.geoApiDescription);
  }

  @RobotKeyword("Create Geo Layer")
  public String createGeoLayer() {
    ensureDataSetId();
    ensureGeoDataSinkId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataSinkId", state.geoDataSinkId);
    body.put("layerName", state.geoLayerName);
    body.put("title", state.geoLayerTitle);
    body.put("description", state.geoLayerDescription);
    ArrayNode keywords = body.putArray("keywords");
    keywords.add("geo");
    keywords.add("system-test");
    ArrayNode attributes = body.putArray("attribute");
    attributes.add(state.geoLayerAttribute);
    body.put("geometryColumnRef", state.geoLayerGeometryColumnRef);
    body.put("cqlFilter", "");
    body.putNull("defaultStyleId");
    body.set("alternativeStyleIds", mapper.createArrayNode());
    body.put("crs", state.geoLayerCrs);
    body.put("bboxAutoCalculate", true);
    body.set("nativeBoundingBox", mapper.nullNode());
    body.set("latLonBoundingBox", mapper.nullNode());

    JsonNode result = portalClient.postJson("/datasets/" + state.dataSetId + "/layers", body, state.accessToken, 201).json();
    state.geoLayerId = requiredText(result, "id", "geoLayer");
    validateGeoLayerPayload(result);
    return state.geoLayerId;
  }

  @RobotKeyword("Verify Geo Layer Snapshot")
  public void verifyGeoLayerSnapshot() {
    ensureDataSetId();
    ensureGeoLayerId();
    JsonNode layer = portalClient
        .getJson("/datasets/" + state.dataSetId + "/layers/" + state.geoLayerId, state.accessToken, 200)
        .json();
    validateGeoLayerPayload(layer);
  }

  @RobotKeyword("Stage Data Set")
  public void stageDataSet() {
    ensureDataSetId();
    portalClient.postVoid("/datasets/" + state.dataSetId + "/stage", state.accessToken, 200);
  }

  @RobotKeyword("Release Data Set")
  public void releaseDataSet() {
    ensureDataSetId();
    portalClient.postVoid("/datasets/" + state.dataSetId + "/release", state.accessToken, 200);
  }

  @RobotKeyword("Wait For Data Set Status")
  @ArgumentNames({"expectedStatus=READY", "timeoutSeconds=60", "pollSeconds=2"})
  public void waitForDataSetStatusKeyword(String expectedStatus, String timeoutSeconds, String pollSeconds) {
    ensureDataSetId();
    waitForDatasetStatus(
        firstNonBlank(expectedStatus, "READY"),
        Duration.ofSeconds(parsePositiveInt(timeoutSeconds, 60)),
        Duration.ofSeconds(parsePositiveInt(pollSeconds, 2)));
  }

  @RobotKeyword("Wait For Data Set Available")
  @ArgumentNames({"timeoutSeconds=180", "pollSeconds=2"})
  public String waitForDataSetAvailable(String timeoutSeconds, String pollSeconds) {
    ensureDataSetId();
    Duration timeout = Duration.ofSeconds(parsePositiveInt(timeoutSeconds, 180));
    Duration interval = Duration.ofSeconds(parsePositiveInt(pollSeconds, 2));
    JsonNode dataset = waitForDatasetReady(timeout, interval);
    state.publicUrl = requiredText(dataset, "publicUrl", "dataSet.publicUrl");
    state.namedApiPreviewUrl = previewUrl(dataset);
    state.pendingSagaType = textOrNull(dataset, "pendingSagaType");
    validateDataSetPayload(dataset, "AVAILABLE", true);
    return state.publicUrl;
  }

  @RobotKeyword("Verify Data Set Snapshot")
  public void verifyDataSetSnapshot() {
    ensureDataSetId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    validateDataSetPayload(dataset, "AVAILABLE", true);
  }

  @RobotKeyword("Change Data Set Access To Protected")
  public void changeDataSetAccessToProtected() {
    ensureDataSetId();
    ObjectNode body = mapper.createObjectNode();
    body.put("openDataAccess", false);
    JsonNode result = portalClient.patchJson("/datasets/" + state.dataSetId, body, state.accessToken, 200).json();
    state.openDataAccess = false;
    validateDataSetPayload(result, "AVAILABLE", true);
  }

  @RobotKeyword("Verify Gateway Access")
  @ArgumentNames({"expectedStatus=200", "withAuthentication=false"})
  public void verifyGatewayAccess(String expectedStatus, String withAuthentication) {
    ensureNamedApiPreviewUrl();
    int status = parsePositiveInt(expectedStatus, 200);
    boolean authenticated = parseBoolean(withAuthentication);
    Map<String, String> headers = authenticated ? Map.of("X-Allowed-Scope-Ids", "*") : Map.of();
    String bearerToken = authenticated ? state.accessToken : null;
    ApiResponse response = portalClient.getText(state.namedApiPreviewUrl, bearerToken, headers, status);
    if (status == 200) {
      assertTrue(!response.body().isBlank(), "Gateway response body must not be empty");
      assertTrue(response.contentType().contains("json") || response.body().trim().startsWith("{")
          || response.body().trim().startsWith("["), "Gateway response should be JSON");
      assertGatewayResponseContainsExpectedThing(response.json());
    }
  }

  @RobotKeyword("Verify Gateway Response Content")
  @ArgumentNames({"expectedThingName=", "expectedDescription="})
  public void verifyGatewayResponseContent(String expectedThingName, String expectedDescription) {
    ensureNamedApiPreviewUrl();
    String bearerToken = state.openDataAccess ? null : state.accessToken;
    Map<String, String> headers = state.openDataAccess ? Map.of() : Map.of("X-Allowed-Scope-Ids", "*");
    ApiResponse response = portalClient.getText(state.namedApiPreviewUrl, bearerToken, headers, 200);
    assertGatewayResponseContainsExpectedThing(
        response.json(),
        firstNonBlank(expectedThingName, state.expectedGatewayThingName),
        firstNonBlank(expectedDescription, state.expectedGatewayThingDescription));
  }

  private void cleanupDataSet() {
    if (state.dataSetId == null) {
      return;
    }
    try {
      JsonNode current = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
      String status = requiredText(current, "dataSetStatus", "dataSet.dataSetStatus");
      if ("AVAILABLE".equals(status)) {
        portalClient.postVoid("/datasets/" + state.dataSetId + "/unrelease", state.accessToken, 200);
        waitForDatasetStatus("DRAFT", Duration.ofSeconds(90), Duration.ofSeconds(2));
      } else if ("READY".equals(status)) {
        portalClient.postVoid("/datasets/" + state.dataSetId + "/unstage", state.accessToken, 200);
      }
      portalClient.delete("/datasets/" + state.dataSetId, state.accessToken, 204);
    } finally {
      state.dataSetId = null;
      state.pipelineId = null;
      state.publicUrl = null;
      state.namedApiPreviewUrl = null;
    }
  }

  private void cleanupDataSource() {
    if (state.dataSourceId == null) {
      return;
    }
    try {
      JsonNode current = portalClient.getJson("/datasources/" + state.dataSourceId, state.accessToken, 200).json();
      String status = requiredText(current, "dataSourceStatus", "dataSource.dataSourceStatus");
      if ("AVAILABLE".equals(status)) {
        portalClient.postVoid("/datasources/" + state.dataSourceId + "/unrelease", state.accessToken, 200);
        waitForResourceStatus(
            () -> portalClient.getJson("/datasources/" + state.dataSourceId, state.accessToken, 200).json(),
            "dataSourceStatus",
            "DRAFT",
            Duration.ofSeconds(60),
            Duration.ofSeconds(2));
      }
      portalClient.delete("/datasources/" + state.dataSourceId, state.accessToken, 204);
    } finally {
      state.dataSourceId = null;
    }
  }

  private void cleanupDataStructure() {
    if (state.dataStructureId == null) {
      return;
    }
    try {
      JsonNode current = portalClient.getJson("/datastructures/" + state.dataStructureId, state.accessToken, 200).json();
      String status = requiredText(current, "dataStructureStatus", "dataStructure.dataStructureStatus");
      if ("AVAILABLE".equals(status)) {
        portalClient.postVoid("/datastructures/" + state.dataStructureId + "/unrelease", state.accessToken, 200);
        waitForResourceStatus(
            () -> portalClient.getJson("/datastructures/" + state.dataStructureId, state.accessToken, 200).json(),
            "dataStructureStatus",
            "DRAFT",
            Duration.ofSeconds(60),
            Duration.ofSeconds(2));
      }
      portalClient.delete("/datastructures/" + state.dataStructureId, state.accessToken, 204);
    } finally {
      state.dataStructureId = null;
      state.dataStructureVersionId = null;
    }
  }

  private JsonNode waitForDatasetStatus(String expectedStatus, Duration timeout, Duration interval) {
    return waitForResourceStatus(
        () -> portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json(),
        "dataSetStatus",
        expectedStatus,
        timeout,
        interval);
  }

  private JsonNode waitForDatasetReady(Duration timeout, Duration interval) {
    long deadline = System.nanoTime() + timeout.toNanos();
    JsonNode last = null;
    while (System.nanoTime() < deadline) {
      last = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
      String status = textOrNull(last, "dataSetStatus");
      String pendingSaga = textOrNull(last, "pendingSagaType");
      String publicUrl = textOrNull(last, "publicUrl");
      String previewUrl = previewUrlOrNull(last);
      if ("AVAILABLE".equals(status)
          && (pendingSaga == null || pendingSaga.isBlank())
          && publicUrl != null
          && !publicUrl.isBlank()
          && previewUrl != null
          && !previewUrl.isBlank()) {
        return last;
      }
      sleep(interval);
    }
    throw new AssertionError(
        "Timed out waiting for dataset to become AVAILABLE with a public URL. Last response: "
            + (last == null ? "<none>" : last.toPrettyString()));
  }

  private JsonNode waitForResourceStatus(
      ResourceSupplier supplier,
      String statusField,
      String expectedStatus,
      Duration timeout,
      Duration interval) {
    long deadline = System.nanoTime() + timeout.toNanos();
    JsonNode last = null;
    while (System.nanoTime() < deadline) {
      last = supplier.get();
      String status = textOrNull(last, statusField);
      if (expectedStatus.equals(status)) {
        return last;
      }
      sleep(interval);
    }
    throw new AssertionError(
        "Timed out waiting for status " + expectedStatus + " in field " + statusField + ". Last response: "
            + (last == null ? "<none>" : last.toPrettyString()));
  }


  private void ensureInitialized() {
    if (state.runSuffix == null || state.runSuffix.isBlank()) {
      throw new IllegalStateException("System test run has not been initialized");
    }
  }

  private void ensureDataSetId() {
    ensureInitialized();
    if (state.dataSetId == null) {
      throw new IllegalStateException("Dataset has not been created yet");
    }
  }

  private void ensureDataSourceId() {
    ensureInitialized();
    if (state.dataSourceId == null) {
      throw new IllegalStateException("Datasource has not been created yet");
    }
  }

  private void ensureDataStructureId() {
    ensureInitialized();
    if (state.dataStructureId == null) {
      throw new IllegalStateException("Data structure has not been created yet");
    }
  }

  private void ensureDataStructureVersionId() {
    ensureDataStructureId();
    if (state.dataStructureVersionId == null) {
      throw new IllegalStateException("Data structure version has not been created yet");
    }
  }

  private void ensureGeoDataSinkId() {
    ensureDataSetId();
    if (state.geoDataSinkId == null) {
      throw new IllegalStateException("Geo data sink has not been created yet");
    }
  }

  private void ensureGeoLayerId() {
    ensureDataSetId();
    if (state.geoLayerId == null) {
      throw new IllegalStateException("Geo layer has not been created yet");
    }
  }

  private void ensureNamedApiPreviewUrl() {
    ensureDataSetId();
    if (state.namedApiPreviewUrl == null || state.namedApiPreviewUrl.isBlank()) {
      throw new IllegalStateException("Named API preview URL is not available yet");
    }
  }

  private String previewUrl(JsonNode dataset) {
    String preview = previewUrlOrNull(dataset);
    if (preview == null || preview.isBlank()) {
      throw new IllegalStateException("Dataset response does not contain a named API preview URL");
    }
    return preview;
  }

  private String previewUrlOrNull(JsonNode dataset) {
    JsonNode namedApis = dataset.path("namedApis");
    if (namedApis.isArray() && !namedApis.isEmpty()) {
      String preview = textOrNull(namedApis.get(0), "previewUrl");
      if (preview != null && !preview.isBlank()) {
        return preview;
      }
    }
    return null;
  }

  private void safe(String label, Runnable action) {
    try {
      action.run();
    } catch (Exception ex) {
      System.err.println("[WARN] Cleanup step failed for " + label + ": " + ex.getMessage());
    }
  }

  private String readResource(String path) {
    try (InputStream input = getClass().getResourceAsStream(path)) {
      if (input == null) {
        throw new IllegalStateException("Missing test resource: " + path);
      }
      return new String(input.readAllBytes(), StandardCharsets.UTF_8);
    } catch (IOException ex) {
      throw new UncheckedIOException("Failed to read test resource: " + path, ex);
    }
  }

  private String requiredText(JsonNode node, String field, String label) {
    String value = textOrNull(node, field);
    if (value == null || value.isBlank()) {
      throw new AssertionError(label + " must be present. Response: " + node.toPrettyString());
    }
    return value;
  }

  private String textOrNull(JsonNode node, String field) {
    if (node == null || node.isNull()) {
      return null;
    }
    JsonNode fieldNode = node.path(field);
    if (fieldNode.isMissingNode() || fieldNode.isNull()) {
      return null;
    }
    String value = fieldNode.asText();
    return value.isBlank() ? null : value;
  }

  private void assertTextEquals(String expected, String actual) {
    if (!Objects.equals(expected, actual)) {
      throw new AssertionError("Expected '" + expected + "' but got '" + actual + "'");
    }
  }

  private void assertNullOrEmpty(String value, String message) {
    if (value != null && !value.isBlank()) {
      throw new AssertionError(message + ": " + value);
    }
  }

  private void assertTrue(boolean condition, String message) {
    if (!condition) {
      throw new AssertionError(message);
    }
  }

  private int parsePositiveInt(String raw, int fallback) {
    if (raw == null || raw.isBlank()) {
      return fallback;
    }
    try {
      int value = Integer.parseInt(raw.trim());
      return value > 0 ? value : fallback;
    } catch (NumberFormatException ex) {
      return fallback;
    }
  }

  private void sleep(Duration duration) {
    try {
      Thread.sleep(duration.toMillis());
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new RuntimeException("Interrupted while waiting for the dataset to become available", ex);
    }
  }

  private void validateDataStructurePayload(JsonNode dataStructure, String expectedStatus, boolean expectVersionReference) {
    assertTrue(dataStructure.isObject(), "dataStructure response must be a JSON object");
    assertTextEquals(state.dataStructureId, requiredText(dataStructure, "id", "dataStructure.id"));
    assertTextEquals(state.dataStructureName, requiredText(dataStructure, "name", "dataStructure.name"));
    assertTextEquals(
        "Data structure for the dataset saga system test",
        requiredText(dataStructure, "description", "dataStructure.description"));
    assertTextEquals(
        expectedStatus,
        requiredText(dataStructure, "dataStructureStatus", "dataStructure.dataStructureStatus"));
    assertBooleanEquals(
        false,
        dataStructure.path("createdFromDataSource").asBoolean(true),
        "dataStructure.createdFromDataSource");
    assertIsArray(dataStructure.path("dataStructureVersionIds"), "dataStructure.dataStructureVersionIds");
    assertIsArray(dataStructure.path("assignments"), "dataStructure.assignments");
    if (expectVersionReference) {
      ensureDataStructureVersionId();
      assertArrayContainsText(
          dataStructure.path("dataStructureVersionIds"),
          state.dataStructureVersionId,
          "dataStructure.dataStructureVersionIds");
    }
  }

  private void validateDataStructureVersionPayload(JsonNode version) {
    assertTrue(version.isObject(), "dataStructureVersion response must be a JSON object");
    assertTextEquals(state.dataStructureVersionId, requiredText(version, "id", "dataStructureVersion.id"));
    assertTextEquals("OWN", requiredText(version, "dataStructureVersionSource", "dataStructureVersion.dataStructureVersionSource"));
    assertTextEquals("1.0.0", requiredText(version, "version", "dataStructureVersion.version"));
    assertTextEquals(
        "Initial release for the system test proof of concept",
        requiredText(version, "description", "dataStructureVersion.description"));
    assertTextEquals(state.modelAtlasUri, requiredText(version, "modelAtlasUri", "dataStructureVersion.modelAtlasUri"));
    assertTextEquals(state.modelName, requiredText(version, "modelName", "dataStructureVersion.modelName"));
    assertTrue(
        requiredText(version, "model", "dataStructureVersion.model").contains("<uml:Model"),
        "dataStructureVersion.model must contain the serialized UML model");
    assertIsObject(version.path("styles"), "dataStructureVersion.styles");
  }

  private void validateDataSourcePayload(JsonNode dataSource, String expectedStatus, boolean expectDataStructureVersion) {
    assertTrue(dataSource.isObject(), "dataSource response must be a JSON object");
    assertTextEquals(state.dataSourceId, requiredText(dataSource, "id", "dataSource.id"));
    assertTextEquals(state.dataSourceName, requiredText(dataSource, "name", "dataSource.name"));
    assertTextEquals(
        "MQTT datasource for the system test proof of concept",
        requiredText(dataSource, "description", "dataSource.description"));
    assertTextEquals("MQTT", requiredText(dataSource, "connectorType", "dataSource.connectorType"));
    assertTextEquals(expectedStatus, requiredText(dataSource, "dataSourceStatus", "dataSource.dataSourceStatus"));
    JsonNode configuration = dataSource.path("configuration");
    assertIsObject(configuration, "dataSource.configuration");
    assertArrayContainsText(configuration.path("urls"), "tcp://broker.hivemq.com:1883", "dataSource.configuration.urls");
    assertArrayContainsText(
        configuration.path("topics"),
        "+/civitas+/civitas/core/energy/meter/+/taf10",
        "dataSource.configuration.topics");
    assertTextEquals(
        state.dataSourceClientId,
        requiredText(configuration, "client_id", "dataSource.configuration.client_id"));
    assertTextEquals("1", requiredText(configuration, "qos", "dataSource.configuration.qos"));
    assertTextEquals("5s", requiredText(configuration, "connect_timeout", "dataSource.configuration.connect_timeout"));
    assertTextEquals("30s", requiredText(configuration, "keepalive", "dataSource.configuration.keepalive"));
    assertBooleanEquals(false, configuration.path("tls").path("enabled").asBoolean(true), "dataSource.configuration.tls.enabled");
    if (expectDataStructureVersion) {
      ensureDataStructureVersionId();
      assertTextEquals(
          state.dataStructureVersionId,
          requiredText(dataSource, "dataStructureVersionId", "dataSource.dataStructureVersionId"));
    } else {
      assertNullOrEmpty(
          textOrNull(dataSource, "dataStructureVersionId"),
          "dataSource.dataStructureVersionId should be empty before the patch");
    }
  }

  private void validateDataSetPayload(JsonNode dataset, String expectedStatus, boolean expectPublicRoutes) {
    assertTextEquals(state.dataSetId, requiredText(dataset, "id", "dataSet.id"));
    assertTextEquals(state.dataSetName, requiredText(dataset, "name", "dataSet.name"));
    assertTextEquals(
        "Dataset for the system test proof of concept",
        requiredText(dataset, "description", "dataSet.description"));
    assertTextEquals(expectedStatus, requiredText(dataset, "dataSetStatus", "dataSet.dataSetStatus"));
    assertBooleanEquals(
        state.openDataAccess,
        dataset.path("openDataAccess").asBoolean(!state.openDataAccess),
        "dataSet.openDataAccess");
    JsonNode namedApis = dataset.path("namedApis");
    assertTrue(namedApis.isArray() && !namedApis.isEmpty(), "dataSet.namedApis must contain at least one entry");
    JsonNode namedApi = namedApis.get(0);
    assertTextEquals("Things", requiredText(namedApi, "name", "dataSet.namedApis[0].name"));
    assertTextEquals(state.namedApiSlug, requiredText(namedApi, "slug", "dataSet.namedApis[0].slug"));
    assertTextEquals("STA", requiredText(namedApi, "standard", "dataSet.namedApis[0].standard"));
    assertTextEquals("1.1", requiredText(namedApi, "version", "dataSet.namedApis[0].version"));
    if (expectPublicRoutes) {
      assertNullOrEmpty(textOrNull(dataset, "pendingSagaType"), "pendingSagaType should be null after the saga");
      state.publicUrl = requiredText(dataset, "publicUrl", "dataSet.publicUrl");
      state.namedApiPreviewUrl = previewUrl(dataset);
      assertTrue(!state.publicUrl.isBlank(), "publicUrl must be present after release");
      assertTrue(
          state.namedApiPreviewUrl.contains("/v1/datasets/" + state.dataSetId + "/" + state.namedApiSlug),
          "Named API previewUrl must point to the public route");
      assertTrue(
          requiredText(namedApi, "previewUrl", "dataSet.namedApis[0].previewUrl").equals(state.namedApiPreviewUrl),
          "Named API previewUrl must match the stored preview URL");
    }
  }

  private void validatePipelinePayload(JsonNode pipeline) {
    assertTrue(pipeline.isObject(), "pipeline response must be a JSON object");
    assertTextEquals(state.pipelineId, requiredText(pipeline, "id", "pipeline.id"));
    assertTextEquals(state.pipelineName, requiredText(pipeline, "name", "pipeline.name"));
    assertTextEquals(state.pipelineDescription, requiredText(pipeline, "description", "pipeline.description"));
    assertArrayContainsText(pipeline.path("dataSourceIds"), state.dataSourceId, "pipeline.dataSourceIds");
    assertIsObject(pipeline.path("styles"), "pipeline.styles");
    JsonNode model = pipeline.path("model");
    assertIsObject(model, "pipeline.model");
    JsonNode generate = model.path("input").path("generate");
    assertIsObject(generate, "pipeline.model.input.generate");
    assertTextEquals("1s", requiredText(generate, "interval", "pipeline.model.input.generate.interval"));
    assertTextEquals("1", requiredText(generate, "count", "pipeline.model.input.generate.count"));
    assertTrue(
        requiredText(generate, "mapping", "pipeline.model.input.generate.mapping").contains(state.expectedGatewayThingName),
        "pipeline mapping must contain the expected thing name");
    JsonNode httpClientConfig = model.path("output").path("http_client");
    assertIsObject(httpClientConfig, "pipeline.model.output.http_client");
    assertTextEquals(
        config.frostBaseUrl + "/Things",
        requiredText(httpClientConfig, "url", "pipeline.model.output.http_client.url"));
    assertTextEquals(
        "POST",
        requiredText(httpClientConfig, "verb", "pipeline.model.output.http_client.verb"));
    assertTextEquals(
        "application/json",
        requiredText(httpClientConfig.path("headers"), "Content-Type", "pipeline.model.output.http_client.headers.Content-Type"));
  }

  private void assertGatewayResponseContainsExpectedThing(JsonNode responseJson) {
    assertGatewayResponseContainsExpectedThing(
        responseJson,
        state.expectedGatewayThingName,
        state.expectedGatewayThingDescription);
  }

  private void assertGatewayResponseContainsExpectedThing(
      JsonNode responseJson,
      String expectedThingName,
      String expectedDescription) {
    JsonNode entities = gatewayEntities(responseJson);
    assertTrue(entities.isArray() && !entities.isEmpty(), "Gateway JSON response must contain at least one entity");
    boolean found = false;
    for (JsonNode entity : entities) {
      String name = textOrNull(entity, "name");
      String description = textOrNull(entity, "description");
      if (Objects.equals(expectedThingName, name) && Objects.equals(expectedDescription, description)) {
        found = true;
        break;
      }
    }
    assertTrue(
        found,
        "Gateway response must contain an entity with name '"
            + expectedThingName
            + "' and description '"
            + expectedDescription
            + "'. Response: "
            + responseJson.toPrettyString());
  }

  private JsonNode gatewayEntities(JsonNode responseJson) {
    if (responseJson == null || responseJson.isNull()) {
      return JsonNodeFactory.instance.arrayNode();
    }
    if (responseJson.isArray()) {
      return responseJson;
    }
    JsonNode value = responseJson.path("value");
    if (value.isArray()) {
      return value;
    }
    if (responseJson.isObject()) {
      ArrayNode single = mapper.createArrayNode();
      single.add(responseJson);
      return single;
    }
    return JsonNodeFactory.instance.arrayNode();
  }

  private void assertArrayContainsText(JsonNode arrayNode, String expectedValue, String label) {
    assertTrue(arrayNode.isArray(), label + " must be an array");
    for (JsonNode node : arrayNode) {
      if (Objects.equals(expectedValue, node.asText())) {
        return;
      }
    }
    throw new AssertionError(label + " must contain '" + expectedValue + "'. Response: " + arrayNode.toPrettyString());
  }

  private void assertBooleanEquals(boolean expected, boolean actual, String label) {
    if (expected != actual) {
      throw new AssertionError(label + " expected '" + expected + "' but got '" + actual + "'");
    }
  }

  private void assertIsArray(JsonNode node, String label) {
    assertTrue(node.isArray(), label + " must be a JSON array");
  }

  private void assertIsObject(JsonNode node, String label) {
    assertTrue(node.isObject(), label + " must be a JSON object");
  }

  private JsonNode responseJsonOrFetch(ApiResponse response, ResourceSupplier fallback, String operationLabel) {
    if (!response.json().isNull() && !response.json().isMissingNode()) {
      return response.json();
    }
    JsonNode fallbackJson = fallback.get();
    assertTrue(
        fallbackJson != null && !fallbackJson.isNull() && !fallbackJson.isMissingNode(),
        operationLabel + " must provide a JSON response or a readable follow-up resource");
    return fallbackJson;
  }

  private ObjectNode buildPipelinePayload(String pipelineName, String pipelineDescription) {
    ObjectNode body = mapper.createObjectNode();
    body.put("name", pipelineName);
    body.put("description", pipelineDescription);
    ArrayNode dataSourceIds = body.putArray("dataSourceIds");
    dataSourceIds.add(state.dataSourceId);
    body.set("styles", mapper.createObjectNode());

    ObjectNode model = body.putObject("model");
    ObjectNode input = model.putObject("input");
    ObjectNode generate = input.putObject("generate");
    generate.put("interval", "1s");
    generate.put("count", 1);
    generate.put("mapping", "root = {\"name\": \"Test Sensor\", \"description\": \"test\"}");
    ObjectNode output = model.putObject("output");
    ObjectNode httpClient = output.putObject("http_client");
    httpClient.put("url", config.frostBaseUrl + "/Things");
    httpClient.put("verb", "POST");
    ObjectNode headers = httpClient.putObject("headers");
    headers.put("Content-Type", "application/json");
    return body;
  }

  private void validateGeoPipelinePayload(JsonNode pipeline) {
    assertTrue(pipeline.isObject(), "geo pipeline response must be a JSON object");
    assertTextEquals(state.geoPipelineId, requiredText(pipeline, "id", "geoPipeline.id"));
    assertTextEquals(state.geoPipelineName, requiredText(pipeline, "name", "geoPipeline.name"));
    assertTextEquals(
        state.geoPipelineDescription,
        requiredText(pipeline, "description", "geoPipeline.description"));
    assertArrayContainsText(pipeline.path("dataSourceIds"), state.dataSourceId, "geoPipeline.dataSourceIds");
    JsonNode dataSinks = pipeline.path("dataSinks");
    assertTrue(dataSinks.isArray() && !dataSinks.isEmpty(), "geoPipeline.dataSinks must contain at least one sink");
    JsonNode sink = dataSinks.get(0);
    assertTextEquals(state.geoDataSinkId, requiredText(sink, "id", "geoPipeline.dataSinks[0].id"));
    assertTextEquals("POSTGIS", requiredText(sink, "dataSinkType", "geoPipeline.dataSinks[0].dataSinkType"));
    JsonNode configuration = sink.path("configuration");
    assertIsObject(configuration, "geoPipeline.dataSinks[0].configuration");
    assertTextEquals(
        state.geoDataSinkTableName,
        requiredText(configuration, "tableName", "geoPipeline.dataSinks[0].configuration.tableName"));
    JsonNode dsv = configuration.path("dataStructureVersion");
    assertIsObject(dsv, "geoPipeline.dataSinks[0].configuration.dataStructureVersion");
    assertTextEquals(
        state.dataStructureVersionId,
        requiredText(dsv, "id", "geoPipeline.dataSinks[0].configuration.dataStructureVersion.id"));
  }

  private void validateNamedApiPresence(
      JsonNode dataset,
      String slug,
      String expectedName,
      String expectedStandard,
      String expectedDescription) {
    JsonNode namedApis = dataset.path("namedApis");
    assertTrue(namedApis.isArray() && !namedApis.isEmpty(), "dataset.namedApis must contain at least one entry");
    JsonNode match = null;
    for (JsonNode candidate : namedApis) {
      if (Objects.equals(slug, textOrNull(candidate, "slug"))) {
        match = candidate;
        break;
      }
    }
    if (match == null) {
      throw new AssertionError("dataset.namedApis must contain slug '" + slug + "'. Response: " + dataset.toPrettyString());
    }
    assertTextEquals(expectedName, requiredText(match, "name", "dataset.namedApis[" + slug + "].name"));
    assertTextEquals(expectedStandard, requiredText(match, "standard", "dataset.namedApis[" + slug + "].standard"));
    if (expectedDescription != null) {
      assertTextEquals(
          expectedDescription,
          requiredText(match, "description", "dataset.namedApis[" + slug + "].description"));
    }
  }

  private void validateGeoLayerPayload(JsonNode layer) {
    assertTrue(layer.isObject(), "geo layer response must be a JSON object");
    assertTextEquals(state.geoLayerId, requiredText(layer, "id", "geoLayer.id"));
    assertTextEquals(state.dataSetId, requiredText(layer, "dataSetId", "geoLayer.dataSetId"));
    assertTextEquals(state.geoDataSinkId, requiredText(layer, "dataSinkId", "geoLayer.dataSinkId"));
    assertTextEquals(state.geoLayerName, requiredText(layer, "layerName", "geoLayer.layerName"));
    assertTextEquals(state.geoLayerTitle, requiredText(layer, "title", "geoLayer.title"));
    assertTextEquals(
        state.geoLayerDescription, requiredText(layer, "description", "geoLayer.description"));
    assertArrayContainsText(layer.path("keywords"), "geo", "geoLayer.keywords");
    assertArrayContainsText(layer.path("attribute"), state.geoLayerAttribute, "geoLayer.attribute");
    assertTextEquals(
        state.geoLayerGeometryColumnRef,
        requiredText(layer, "geometryColumnRef", "geoLayer.geometryColumnRef"));
    assertTextEquals(state.geoLayerCrs, requiredText(layer, "crs", "geoLayer.crs"));
    assertBooleanEquals(true, layer.path("bboxAutoCalculate").asBoolean(false), "geoLayer.bboxAutoCalculate");
  }

  static String firstNonBlank(String first, String second) {
    if (first != null && !first.isBlank()) {
      return first.trim();
    }
    return second;
  }

  private static String sanitizeSuffix(String suffix) {
    return suffix == null ? "" : suffix.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
  }

  private static boolean parseBoolean(String raw) {
    return raw != null && Boolean.parseBoolean(raw.trim());
  }

  private static String generatedSuffix() {
    return Long.toString(Math.abs(ThreadLocalRandom.current().nextLong()), 36)
        + "-"
        + UUID.randomUUID().toString().substring(0, 8);
  }
}
