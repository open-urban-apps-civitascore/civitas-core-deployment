package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.time.Duration;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

import static de.civitascore.systemtests.keywords.KeywordAssertions.*;

@RobotKeywords
public class DataSourceKeywords {

  private final SystemTestState state = TestContext.state();
  private final ObjectMapper mapper = TestContext.mapper();
  private final PortalBackendClient portalClient = TestContext.portalClient();

  @RobotKeyword("Get Generated Data Source Name")
  public String getGeneratedDataSourceName() {
    ensureInitialized();
    return state.dataSourceName;
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
    validateDataSourcePayload(dataSource, expectedStatus, KeywordUtils.parseBoolean(expectDataStructureVersion));
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

  void cleanupDataSource() {
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
          requiredText(dataSource.path("dataStructureVersion"), "id", "dataSource.dataStructureVersion.id"));
    } else {
      assertTrue(
          dataSource.path("dataStructureVersion").isNull() || dataSource.path("dataStructureVersion").isMissingNode(),
          "dataSource.dataStructureVersion should be absent before the patch");
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

  private void ensureDataStructureVersionId() {
    ensureInitialized();
    if (state.dataStructureVersionId == null) {
      throw new IllegalStateException("Data structure version has not been created yet");
    }
  }
}
