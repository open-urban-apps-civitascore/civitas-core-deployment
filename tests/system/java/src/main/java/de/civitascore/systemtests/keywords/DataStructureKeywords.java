package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.time.Duration;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

import static de.civitascore.systemtests.keywords.KeywordAssertions.*;

@RobotKeywords
public class DataStructureKeywords {

  private final SystemTestState state = TestContext.state();
  private final ObjectMapper mapper = TestContext.mapper();
  private final PortalBackendClient portalClient = TestContext.portalClient();

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
    validateDataStructurePayload(dataStructure, expectedStatus, KeywordUtils.parseBoolean(expectVersionReference));
  }

  @RobotKeyword("Create Data Structure Version")
  public String createDataStructureVersion() {
    ensureDataStructureId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataStructureVersionSource", "OWN");
    body.put("version", "1.0.0");
    body.put("description", "Initial release for the system test proof of concept");
    body.put("modelName", state.modelName);
    ObjectNode model = mapper.createObjectNode();
    ObjectNode properties = model.putObject("properties");
    properties.putObject("value").put("type", "string");
    body.set("model", model);
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

  void cleanupDataStructure() {
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
    assertIsArray(dataStructure.path("dataStructureVersions"), "dataStructure.dataStructureVersions");
    if (expectVersionReference) {
      ensureDataStructureVersionId();
      assertArrayContainsObjectWithId(
          dataStructure.path("dataStructureVersions"),
          state.dataStructureVersionId,
          "dataStructure.dataStructureVersions");
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
    assertTextEquals(state.modelName, requiredText(version, "modelName", "dataStructureVersion.modelName"));
    assertIsObject(version.path("model"), "dataStructureVersion.model");
    assertIsObject(version.path("styles"), "dataStructureVersion.styles");
  }

  private void ensureInitialized() {
    if (state.runSuffix == null || state.runSuffix.isBlank()) {
      throw new IllegalStateException("System test run has not been initialized");
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
}
