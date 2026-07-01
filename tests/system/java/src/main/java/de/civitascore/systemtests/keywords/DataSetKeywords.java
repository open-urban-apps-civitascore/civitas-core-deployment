package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Objects;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

import static de.civitascore.systemtests.keywords.KeywordAssertions.*;

@RobotKeywords
public class DataSetKeywords {

  private final SystemTestState state = TestContext.state();
  private final ObjectMapper mapper = TestContext.mapper();
  private final PortalBackendClient portalClient = TestContext.portalClient();

  @RobotKeyword("Get Generated Data Set Name")
  public String getGeneratedDataSetName() {
    ensureInitialized();
    return state.dataSetName;
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

  @RobotKeyword("Adopt Frontend Data Set")
  public String adoptFrontendDataSet() {
    ensureInitialized();
    JsonNode page = portalClient
        .getJson("/datasets?name=" + URLEncoder.encode(state.dataSetName, StandardCharsets.UTF_8), state.accessToken, 200)
        .json();
    JsonNode content = page.path("content");
    assertTrue(content.isArray(), "GET /datasets must return a paged content array");
    for (JsonNode dataSet : content) {
      if (Objects.equals(state.dataSetName, dataSet.path("name").asText())) {
        state.dataSetId = requiredText(dataSet, "id", "dataSet");
        return state.dataSetId;
      }
    }
    throw new AssertionError(
        "No data set named '" + state.dataSetName + "' found to adopt. Response: " + page.toPrettyString());
  }

  @RobotKeyword("Verify Data Set Snapshot")
  @ArgumentNames({"expectedStatus=DRAFT", "expectPublicRoutes=false"})
  public void verifyDataSetSnapshot(String expectedStatus, String expectPublicRoutes) {
    ensureDataSetId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    validateDataSetPayload(dataset, expectedStatus, KeywordUtils.parseBoolean(expectPublicRoutes));
  }

  @RobotKeyword("Stage Data Set")
  public void stageDataSet() {
    ensureDataSetId();
    portalClient.postVoid("/datasets/" + state.dataSetId + "/stage", state.accessToken, 200);
  }

  @RobotKeyword("Release Data Set")
  public void releaseDataSet() {
    ensureDataSetId();
    portalClient.postVoid("/datasets/" + state.dataSetId + "/release", state.accessToken, 202);
  }

  @RobotKeyword("Wait For Data Set Status")
  @ArgumentNames({"expectedStatus=READY", "timeoutSeconds=60", "pollSeconds=2"})
  public void waitForDataSetStatusKeyword(String expectedStatus, String timeoutSeconds, String pollSeconds) {
    ensureDataSetId();
    waitForDatasetStatus(
        KeywordUtils.firstNonBlank(expectedStatus, "READY"),
        Duration.ofSeconds(KeywordUtils.parsePositiveInt(timeoutSeconds, 60)),
        Duration.ofSeconds(KeywordUtils.parsePositiveInt(pollSeconds, 2)));
  }

  @RobotKeyword("Wait For Data Set Available")
  @ArgumentNames({"timeoutSeconds=180", "pollSeconds=2"})
  public String waitForDataSetAvailable(String timeoutSeconds, String pollSeconds) {
    ensureDataSetId();
    Duration timeout = Duration.ofSeconds(KeywordUtils.parsePositiveInt(timeoutSeconds, 180));
    Duration interval = Duration.ofSeconds(KeywordUtils.parsePositiveInt(pollSeconds, 2));
    JsonNode dataset = waitForDatasetReady(timeout, interval);
    state.publicUrl = requiredText(dataset, "publicUrl", "dataSet.publicUrl");
    state.namedApiPreviewUrl = previewUrl(dataset);
    state.pendingSagaType = textOrNull(dataset, "pendingSagaType");
    validateDataSetPayload(dataset, "AVAILABLE", true);
    return state.publicUrl;
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

  void cleanupDataSet() {
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
}
