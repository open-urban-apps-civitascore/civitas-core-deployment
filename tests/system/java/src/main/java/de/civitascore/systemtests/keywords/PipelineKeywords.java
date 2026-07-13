package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

import static de.civitascore.systemtests.keywords.KeywordAssertions.*;

@RobotKeywords
public class PipelineKeywords {

  private final SystemTestState state = TestContext.state();
  private final ObjectMapper mapper = TestContext.mapper();
  private final PortalBackendClient portalClient = TestContext.portalClient();

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

  @RobotKeyword("Create Pipeline")
  public String createPipeline() {
    ensureDataSetId();
    ensureDataSourceId();
    ensureDataStructureVersionId();

    // FROST sink (empty configuration) — referenced by the Frost node in the pipeline graph.
    ObjectNode sinkBody = mapper.createObjectNode();
    sinkBody.put("dataSinkType", "FROST");
    sinkBody.set("configuration", mapper.createObjectNode());
    JsonNode sinkResult = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/datasinks", sinkBody, state.accessToken, 201).json();
    state.frostDataSinkId = requiredText(sinkResult, "id", "pipeline.dataSink");

    ObjectNode body = buildFrostPipelinePayload();

    JsonNode result = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/pipelines", body, state.accessToken, 201).json();
    state.pipelineId = requiredText(result, "id", "pipeline");
    validatePipelinePayload(result);
    return state.pipelineId;
  }

  /**
   * Builds the (FROST) pipeline request body from a captured pipeline-editor payload
   * (React-Flow node/edge graph), substituting the entities created earlier in the run.
   */
  private ObjectNode buildFrostPipelinePayload() {
    String json = readResourceAsString("/models/frost-pipeline.json")
        .replace("__PIPELINE_NAME__", state.pipelineName)
        .replace("__PIPELINE_DESCRIPTION__", state.pipelineDescription)
        .replace("__DATA_SOURCE_ID__", state.dataSourceId)
        .replace("__DATA_SOURCE_NAME__", state.dataSourceName)
        .replace("__FROST_SINK_ID__", state.frostDataSinkId)
        .replace("__DS_NAME__", state.dataStructureName)
        .replace("__DSV_ID__", state.dataStructureVersionId)
        .replace("__DS_ID__", state.dataStructureId);
    try {
      return (ObjectNode) mapper.readTree(json);
    } catch (IOException ex) {
      throw new UncheckedIOException("Failed to parse pipeline payload", ex);
    }
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

  @RobotKeyword("Create Geo Pipeline")
  public String createGeoPipeline() {
    ensureDataSetId();
    ensureDataSourceId();
    ensureDataStructureVersionId();

    ObjectNode sinkBody = mapper.createObjectNode();
    sinkBody.put("dataSinkType", "POSTGIS");
    ObjectNode sinkConfig = sinkBody.putObject("configuration");
    sinkConfig.put("tableName", state.geoDataSinkTableName);
    sinkConfig.put("dataStructureVersionId", state.dataStructureVersionId);
    JsonNode sinkResult = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/datasinks", sinkBody, state.accessToken, 201).json();
    state.geoDataSinkId = requiredText(sinkResult, "id", "geoPipeline.dataSink");

    ObjectNode body = buildGeoPipelinePayload();

    JsonNode result = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/pipelines", body, state.accessToken, 201).json();
    state.geoPipelineId = requiredText(result, "id", "geoPipeline");
    validateGeoPipelinePayload(result);
    return state.geoPipelineId;
  }

  /**
   * Builds the geo pipeline request body from a captured pipeline-editor payload
   * (React-Flow node/edge graph), substituting the entities created earlier in the run.
   */
  private ObjectNode buildGeoPipelinePayload() {
    String json = readResourceAsString("/models/geo-pipeline.json")
        .replace("__PIPELINE_NAME__", state.geoPipelineName)
        .replace("__PIPELINE_DESCRIPTION__", state.geoPipelineDescription)
        .replace("__DATA_SOURCE_ID__", state.dataSourceId)
        .replace("__DATA_SOURCE_NAME__", state.dataSourceName)
        .replace("__DATA_SINK_ID__", state.geoDataSinkId)
        .replace("__GEO_TABLE_NAME__", state.geoDataSinkTableName)
        .replace("__DS_NAME__", state.dataStructureName)
        .replace("__DSV_ID__", state.dataStructureVersionId)
        .replace("__DS_ID__", state.dataStructureId);
    try {
      return (ObjectNode) mapper.readTree(json);
    } catch (IOException ex) {
      throw new UncheckedIOException("Failed to parse geo pipeline payload", ex);
    }
  }

  private String readResourceAsString(String path) {
    try (InputStream input = getClass().getResourceAsStream(path)) {
      if (input == null) {
        throw new IllegalStateException("Missing test resource: " + path);
      }
      return new String(input.readAllBytes(), StandardCharsets.UTF_8);
    } catch (IOException ex) {
      throw new UncheckedIOException("Failed to read test resource: " + path, ex);
    }
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
    validateOwsDataSetPayload(result);
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

  private void validatePipelinePayload(JsonNode pipeline) {
    assertTrue(pipeline.isObject(), "pipeline response must be a JSON object");
    assertTextEquals(state.pipelineId, requiredText(pipeline, "id", "pipeline.id"));
    assertTextEquals(state.pipelineName, requiredText(pipeline, "name", "pipeline.name"));
    assertTextEquals(state.pipelineDescription, requiredText(pipeline, "description", "pipeline.description"));
    JsonNode dataSinkIds = pipeline.path("dataSinkIds");
    assertTrue(dataSinkIds.isArray() && !dataSinkIds.isEmpty(), "pipeline.dataSinkIds must contain at least one entry");
    assertArrayContainsText(dataSinkIds, state.frostDataSinkId, "pipeline.dataSinkIds");
  }

  private void validateGeoPipelinePayload(JsonNode pipeline) {
    assertTrue(pipeline.isObject(), "geo pipeline response must be a JSON object");
    assertTextEquals(state.geoPipelineId, requiredText(pipeline, "id", "geoPipeline.id"));
    assertTextEquals(state.geoPipelineName, requiredText(pipeline, "name", "geoPipeline.name"));
    assertTextEquals(
        state.geoPipelineDescription,
        requiredText(pipeline, "description", "geoPipeline.description"));
    JsonNode dataSinkIds = pipeline.path("dataSinkIds");
    assertTrue(dataSinkIds.isArray() && !dataSinkIds.isEmpty(), "geoPipeline.dataSinkIds must contain at least one entry");
    assertArrayContainsText(dataSinkIds, state.geoDataSinkId, "geoPipeline.dataSinkIds");
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

  private void validateOwsDataSetPayload(JsonNode dataset) {
    assertTextEquals(state.dataSetId, requiredText(dataset, "id", "dataSet.id"));
    assertTextEquals(state.dataSetName, requiredText(dataset, "name", "dataSet.name"));
    assertTextEquals("DRAFT", requiredText(dataset, "dataSetStatus", "dataSet.dataSetStatus"));
    JsonNode namedApis = dataset.path("namedApis");
    assertTrue(namedApis.isArray() && !namedApis.isEmpty(), "dataSet.namedApis must contain at least one entry");
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

  private void ensureDataStructureVersionId() {
    ensureInitialized();
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

  /**
   * Deletes any pipelines and data sinks created during this run. Must run before {@code
   * DataSetKeywords.cleanupDataSet()} deletes the dataset, which otherwise fails with a foreign
   * key conflict because pipelines/data sinks still reference it.
   */
  void cleanupPipelines() {
    deletePipelineIfPresent(state.pipelineId);
    deletePipelineIfPresent(state.geoPipelineId);
    deleteDataSinkIfPresent(state.frostDataSinkId);
    deleteDataSinkIfPresent(state.geoDataSinkId);
    state.pipelineId = null;
    state.geoPipelineId = null;
    state.frostDataSinkId = null;
    state.geoDataSinkId = null;
  }

  private void deletePipelineIfPresent(String pipelineId) {
    if (pipelineId == null || state.dataSetId == null) {
      return;
    }
    portalClient.delete("/datasets/" + state.dataSetId + "/pipelines/" + pipelineId, state.accessToken, 204);
  }

  private void deleteDataSinkIfPresent(String dataSinkId) {
    if (dataSinkId == null || state.dataSetId == null) {
      return;
    }
    portalClient.delete("/datasets/" + state.dataSetId + "/datasinks/" + dataSinkId, state.accessToken, 204);
  }
}
