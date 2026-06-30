package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.util.Objects;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

@RobotKeywords
public class DatapoolKeywords {

  private final SystemTestState state = TestContext.state();
  private final PortalBackendClient portalClient = TestContext.portalClient();
  private final ObjectMapper mapper = TestContext.mapper();

  public DatapoolKeywords() {}

  @RobotKeyword("Create Data Pool")
  public String createDataPool() {
    ensureInitialized();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", state.dataPoolName);
    body.put("description", "DataPool for the system test proof of concept");

    JsonNode result = portalClient.postJson("/datapools", body, state.accessToken, 201).json();
    state.dataPoolId = requiredText(result, "id", "dataPool");
    validateDataPoolPayload(result);
    return state.dataPoolId;
  }

  @RobotKeyword("Verify Data Pool Snapshot")
  public void verifyDataPoolSnapshot() {
    ensureDataPoolId();
    JsonNode dataPool = portalClient.getJson("/datapools/" + state.dataPoolId, state.accessToken, 200).json();
    validateDataPoolPayload(dataPool);
  }

  @RobotKeyword("Set Data Source Datapool Scope")
  public void setDataSourceDatapoolScope() {
    ensureDataSourceId();
    ensureDataPoolId();
    ObjectNode body = mapper.createObjectNode();
    ObjectNode datapoolScope = body.putObject("datapoolScope");
    datapoolScope.put("type", "SPECIFIC");
    datapoolScope.putArray("datapoolIds").add(state.dataPoolId);

    JsonNode result = portalClient.patchJson("/datasources/" + state.dataSourceId, body, state.accessToken, 200).json();
    validateDataSourceDatapoolScope(result);
  }

  @RobotKeyword("Verify Data Source Datapool Scope")
  public void verifyDataSourceDatapoolScope() {
    ensureDataSourceId();
    ensureDataPoolId();
    JsonNode dataSource = portalClient.getJson("/datasources/" + state.dataSourceId, state.accessToken, 200).json();
    validateDataSourceDatapoolScope(dataSource);
  }

  @RobotKeyword("Assign Data Set To Data Pool")
  public void assignDataSetToDataPool() {
    ensureDataSetId();
    ensureDataPoolId();
    ObjectNode body = mapper.createObjectNode();
    body.put("datapoolId", state.dataPoolId);

    JsonNode result = portalClient.patchJson("/datasets/" + state.dataSetId, body, state.accessToken, 200).json();
    validateDataSetDataPoolAssignment(result);
  }

  @RobotKeyword("Verify Data Set Data Pool Assignment")
  public void verifyDataSetDataPoolAssignment() {
    ensureDataSetId();
    ensureDataPoolId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    validateDataSetDataPoolAssignment(dataset);
  }

  @RobotKeyword("Verify Data Sources Filtered By Data Pool")
  public void verifyDataSourcesFilteredByDataPool() {
    ensureDataSourceId();
    ensureDataPoolId();
    JsonNode page = portalClient
        .getJson("/datasources?datapoolId=" + state.dataPoolId, state.accessToken, 200)
        .json();
    JsonNode content = page.path("content");
    assertTrue(content.isArray() && !content.isEmpty(),
        "DataSources filtered by DataPool must return at least one result");
    boolean found = false;
    for (JsonNode ds : content) {
      if (Objects.equals(state.dataSourceId, textOrNull(ds, "id"))) {
        found = true;
        break;
      }
    }
    assertTrue(found,
        "DataSource " + state.dataSourceId + " must appear in the DataPool-filtered result");
  }

  void cleanupDataPool() {
    if (state.dataPoolId == null) {
      return;
    }
    try {
      portalClient.delete("/datapools/" + state.dataPoolId, state.accessToken, 204);
    } finally {
      state.dataPoolId = null;
    }
  }

  private void ensureInitialized() {
    if (state.runSuffix == null || state.runSuffix.isBlank()) {
      throw new IllegalStateException("System test run has not been initialized");
    }
  }

  private void ensureDataSourceId() {
    ensureInitialized();
    if (state.dataSourceId == null) {
      throw new IllegalStateException("Datasource has not been created yet");
    }
  }

  private void ensureDataSetId() {
    ensureInitialized();
    if (state.dataSetId == null) {
      throw new IllegalStateException("Dataset has not been created yet");
    }
  }

  private void ensureDataPoolId() {
    ensureInitialized();
    if (state.dataPoolId == null) {
      throw new IllegalStateException("DataPool has not been created yet");
    }
  }

  private void validateDataPoolPayload(JsonNode dataPool) {
    assertTrue(dataPool.isObject(), "dataPool response must be a JSON object");
    assertTextEquals(state.dataPoolId, requiredText(dataPool, "id", "dataPool.id"));
    assertTextEquals(state.dataPoolName, requiredText(dataPool, "name", "dataPool.name"));
    assertTextEquals(
        "DataPool for the system test proof of concept",
        requiredText(dataPool, "description", "dataPool.description"));
  }

  private void validateDataSourceDatapoolScope(JsonNode dataSource) {
    JsonNode scope = dataSource.path("datapoolScope");
    assertIsObject(scope, "dataSource.datapoolScope");
    assertTextEquals("SPECIFIC", requiredText(scope, "type", "dataSource.datapoolScope.type"));
    assertArrayContainsText(
        scope.path("datapoolIds"), state.dataPoolId, "dataSource.datapoolScope.datapoolIds");
  }

  private void validateDataSetDataPoolAssignment(JsonNode dataset) {
    JsonNode datapool = dataset.path("datapool");
    assertTrue(datapool.isObject() && !datapool.isNull(), "dataSet.datapool must be present");
    assertTextEquals(state.dataPoolId, requiredText(datapool, "id", "dataSet.datapool.id"));
    assertTextEquals(state.dataPoolName, requiredText(datapool, "name", "dataSet.datapool.name"));
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

  private void assertTrue(boolean condition, String message) {
    if (!condition) {
      throw new AssertionError(message);
    }
  }

  private void assertTextEquals(String expected, String actual) {
    if (!Objects.equals(expected, actual)) {
      throw new AssertionError("Expected '" + expected + "' but got '" + actual + "'");
    }
  }

  private void assertIsObject(JsonNode node, String label) {
    assertTrue(node.isObject(), label + " must be a JSON object");
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
}
