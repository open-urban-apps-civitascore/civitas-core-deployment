package de.civitascore.systemtests;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

@RobotKeywords
public class SystemTestKeywords {

  private final SystemTestConfig config = SystemTestConfig.fromEnvironment();
  private final ObjectMapper mapper = new ObjectMapper();
  private final HttpClient httpClient = HttpClient.newBuilder()
      .connectTimeout(Duration.ofSeconds(15))
      .build();
  private final SystemTestState state = new SystemTestState();
  private final KeycloakClient keycloakClient = new KeycloakClient(config, httpClient, mapper);
  private final PortalBackendClient portalClient = new PortalBackendClient(config, httpClient, mapper);

  @RobotKeyword("Initialize System Test Run")
  @ArgumentNames({"suffix=", "openDataAccess=false"})
  public String initializeSystemTestRun(String suffix, String openDataAccess) {
    state.reset();
    state.runSuffix = sanitizeSuffix(firstNonBlank(suffix, generatedSuffix()));
    state.openDataAccess = parseBoolean(openDataAccess);
    state.accessToken = keycloakClient.getAccessToken();
    state.dataStructureName = "Saga Sensor Data Structure " + state.runSuffix;
    state.dataStructureVersionName = "Saga Sensor Data Structure Version " + state.runSuffix;
    state.dataSourceName = "Saga MQTT DataSource " + state.runSuffix;
    state.dataSetName = "Saga DataSet " + state.runSuffix;
    state.pipelineName = "Saga Pipeline " + state.runSuffix;
    state.pipelineDescription = "Robot/Java system test proof of concept";
    state.dataSourceClientId = "civitas-saga-demo-" + state.runSuffix;
    state.namedApiSlug = "things";
    return state.runSuffix;
  }

  @RobotKeyword("Cleanup System Test Run")
  public void cleanupSystemTestRun() {
    safe("dataset", () -> cleanupDataSet());
    safe("datasource", () -> cleanupDataSource());
    safe("datastructure", () -> cleanupDataStructure());
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
    return state.dataStructureId;
  }

  @RobotKeyword("Create Data Structure Version")
  public String createDataStructureVersion() {
    ensureDataStructureId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataStructureVersionSource", "OWN");
    body.put("version", "1.0.0");
    body.put("description", "Initial release for the system test proof of concept");
    body.put("modelAtlasUri", "http://civitas.org/model/SagaSensorModel/1.0.0");
    body.put("modelName", "SagaSensorModel");
    body.put("model", readResource("/models/simple-model.xmi"));
    body.set("styles", mapper.createObjectNode());

    JsonNode result = portalClient.postJson(
        "/datastructures/" + state.dataStructureId + "/versions", body, state.accessToken, 201).json();
    state.dataStructureVersionId = requiredText(result, "id", "dataStructureVersion");
    return state.dataStructureVersionId;
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
    return state.dataSourceId;
  }

  @RobotKeyword("Patch Data Source With Data Structure Version")
  public void patchDataSourceWithDataStructureVersion() {
    ensureDataSourceId();
    ensureDataStructureVersionId();
    ObjectNode body = mapper.createObjectNode();
    body.put("dataStructureVersionId", state.dataStructureVersionId);
    portalClient.patchJson("/datasources/" + state.dataSourceId, body, state.accessToken, 200);
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
    return state.dataSetId;
  }

  @RobotKeyword("Create Pipeline")
  public String createPipeline() {
    ensureDataSetId();
    ensureDataSourceId();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", state.pipelineName);
    body.put("description", state.pipelineDescription);
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

    JsonNode result = portalClient.postJson(
        "/datasets/" + state.dataSetId + "/pipelines", body, state.accessToken, 201).json();
    state.pipelineId = requiredText(result, "id", "pipeline");
    return state.pipelineId;
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
    return state.publicUrl;
  }

  @RobotKeyword("Verify Data Set Snapshot")
  public void verifyDataSetSnapshot() {
    ensureDataSetId();
    JsonNode dataset = portalClient.getJson("/datasets/" + state.dataSetId, state.accessToken, 200).json();
    assertTextEquals("AVAILABLE", requiredText(dataset, "dataSetStatus", "dataSet.dataSetStatus"));
    assertTextEquals(Boolean.toString(state.openDataAccess), requiredText(dataset, "openDataAccess", "dataSet.openDataAccess"));
    assertNullOrEmpty(textOrNull(dataset, "pendingSagaType"), "pendingSagaType should be null after the saga");
    state.publicUrl = requiredText(dataset, "publicUrl", "dataSet.publicUrl");
    state.namedApiPreviewUrl = previewUrl(dataset);
    assertTrue(!state.publicUrl.isBlank(), "publicUrl must be present after release");
    assertTrue(state.namedApiPreviewUrl.contains("/v1/datasets/" + state.dataSetId + "/" + state.namedApiSlug),
        "Named API previewUrl must point to the public route");
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
    }
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

  private interface ResourceSupplier {
    JsonNode get();
  }

  private static final class SystemTestState {
    private String runSuffix;
    private String accessToken;
    private String dataStructureName;
    private String dataStructureId;
    private String dataStructureVersionName;
    private String dataStructureVersionId;
    private String dataSourceName;
    private String dataSourceId;
    private String dataSourceClientId;
    private String dataSetName;
    private String dataSetId;
    private String pipelineName;
    private String pipelineDescription;
    private String pipelineId;
    private String namedApiSlug;
    private String publicUrl;
    private String namedApiPreviewUrl;
    private String pendingSagaType;
    private boolean openDataAccess;

    private void reset() {
      runSuffix = null;
      accessToken = null;
      dataStructureName = null;
      dataStructureId = null;
      dataStructureVersionName = null;
      dataStructureVersionId = null;
      dataSourceName = null;
      dataSourceId = null;
      dataSourceClientId = null;
      dataSetName = null;
      dataSetId = null;
      pipelineName = null;
      pipelineDescription = null;
      pipelineId = null;
      namedApiSlug = null;
      publicUrl = null;
      namedApiPreviewUrl = null;
      pendingSagaType = null;
      openDataAccess = false;
    }
  }

  private static final class SystemTestConfig {
    private final String backendBaseUrl;
    private final String keycloakBaseUrl;
    private final String keycloakRealm;
    private final String keycloakClientId;
    private final String gatewayBaseUrl;
    private final String frostBaseUrl;
    private final String authUser;
    private final String authPassword;
    private final Duration requestTimeout;

    private SystemTestConfig(
        String backendBaseUrl,
        String keycloakBaseUrl,
        String keycloakRealm,
        String keycloakClientId,
        String gatewayBaseUrl,
        String frostBaseUrl,
        String authUser,
        String authPassword,
        Duration requestTimeout) {
      this.backendBaseUrl = backendBaseUrl;
      this.keycloakBaseUrl = keycloakBaseUrl;
      this.keycloakRealm = keycloakRealm;
      this.keycloakClientId = keycloakClientId;
      this.gatewayBaseUrl = gatewayBaseUrl;
      this.frostBaseUrl = frostBaseUrl;
      this.authUser = authUser;
      this.authPassword = authPassword;
      this.requestTimeout = requestTimeout;
    }

    private static SystemTestConfig fromEnvironment() {
      Map<String, String> env = System.getenv();
      String backendBaseUrl = SystemTestKeywords.firstNonBlank(
          env.get("PORTAL_BACKEND_URL"),
          SystemTestKeywords.firstNonBlank(env.get("API_BASE_URL"), "http://localhost:8089/v1"));
      String keycloakBaseUrl = SystemTestKeywords.firstNonBlank(env.get("KEYCLOAK_URL"), "http://localhost:8080");
      String keycloakRealm = SystemTestKeywords.firstNonBlank(env.get("KEYCLOAK_REALM"), "civitas-core");
      String keycloakClientId = SystemTestKeywords.firstNonBlank(env.get("KEYCLOAK_CLIENT_ID"), "portal-frontend");
      String gatewayBaseUrl = SystemTestKeywords.firstNonBlank(
          env.get("APISIX_GATEWAY_URL"),
          SystemTestKeywords.firstNonBlank(env.get("PUBLIC_GATEWAY_URL"), "http://localhost:9080"));
      String frostBaseUrl = SystemTestKeywords.firstNonBlank(
          env.get("FROST_BASE_URL"),
          "http://frost-frost-frost-server-http.frost/FROST-Server/v1.1");
      String authUser = SystemTestKeywords.firstNonBlank(
          env.get("SYSTEM_TEST_AUTH_USER"),
          SystemTestKeywords.firstNonBlank(env.get("AUTH_USER"), "dev@civitas.local"));
      String authPassword = SystemTestKeywords.firstNonBlank(
          env.get("SYSTEM_TEST_AUTH_PASSWORD"),
          SystemTestKeywords.firstNonBlank(env.get("AUTH_PASSWORD"), "dev123"));
      Duration requestTimeout = Duration.ofSeconds(
          SystemTestKeywords.parseLongOrDefault(env.get("SYSTEM_TEST_HTTP_TIMEOUT_SECONDS"), 30));
      return new SystemTestConfig(
          backendBaseUrl,
          keycloakBaseUrl,
          keycloakRealm,
          keycloakClientId,
          gatewayBaseUrl,
          frostBaseUrl,
          authUser,
          authPassword,
          requestTimeout);
    }
  }

  private static final class KeycloakClient {
    private final SystemTestConfig config;
    private final HttpClient httpClient;
    private final ObjectMapper mapper;

    private KeycloakClient(SystemTestConfig config, HttpClient httpClient, ObjectMapper mapper) {
      this.config = config;
      this.httpClient = httpClient;
      this.mapper = mapper;
    }

    private String getAccessToken() {
      if (config.authUser == null || config.authUser.isBlank()) {
        throw new IllegalStateException("SYSTEM_TEST_AUTH_USER or AUTH_USER must be set");
      }
      if (config.authPassword == null || config.authPassword.isBlank()) {
        throw new IllegalStateException("SYSTEM_TEST_AUTH_PASSWORD or AUTH_PASSWORD must be set");
      }
      String formBody = form(
          Map.of(
              "grant_type", "password",
              "client_id", config.keycloakClientId,
              "username", config.authUser,
              "password", config.authPassword));
      HttpRequest request = HttpRequest.newBuilder()
          .uri(URI.create(config.keycloakBaseUrl
              + "/realms/"
              + encodePath(config.keycloakRealm)
              + "/protocol/openid-connect/token"))
          .timeout(config.requestTimeout)
          .header("Content-Type", "application/x-www-form-urlencoded")
          .POST(HttpRequest.BodyPublishers.ofString(formBody))
          .build();
      ApiResponse response = send(request, 200);
      JsonNode json = response.json();
      String token = json.path("access_token").asText(null);
      if (token == null || token.isBlank()) {
        throw new AssertionError("Keycloak token response did not contain access_token: " + response.body());
      }
      return token;
    }

    private ApiResponse send(HttpRequest request, int expectedStatus) {
      try {
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        return ApiResponse.fromResponse("Keycloak token request", response, mapper, expectedStatus);
      } catch (IOException ex) {
        throw new UncheckedIOException("Keycloak request failed", ex);
      } catch (InterruptedException ex) {
        Thread.currentThread().interrupt();
        throw new RuntimeException("Keycloak request was interrupted", ex);
      }
    }
  }

  private static final class PortalBackendClient {
    private final SystemTestConfig config;
    private final HttpClient httpClient;
    private final ObjectMapper mapper;

    private PortalBackendClient(SystemTestConfig config, HttpClient httpClient, ObjectMapper mapper) {
      this.config = config;
      this.httpClient = httpClient;
      this.mapper = mapper;
    }

    private ApiResponse getJson(String path, String bearerToken, int expectedStatus) {
      return send("GET", path, bearerToken, Map.of(), null, expectedStatus);
    }

    private ApiResponse getText(String absoluteUrl, String bearerToken, int expectedStatus) {
      return sendAbsolute("GET", absoluteUrl, bearerToken, Map.of(), null, expectedStatus);
    }

    private ApiResponse getText(String absoluteUrl, String bearerToken, Map<String, String> headers, int expectedStatus) {
      return sendAbsolute("GET", absoluteUrl, bearerToken, headers, null, expectedStatus);
    }

    private ApiResponse postJson(String path, JsonNode body, String bearerToken, int expectedStatus) {
      return send("POST", path, bearerToken, Map.of(), body, expectedStatus);
    }

    private ApiResponse patchJson(String path, JsonNode body, String bearerToken, int expectedStatus) {
      return send("PATCH", path, bearerToken, Map.of(), body, expectedStatus);
    }

    private ApiResponse postVoid(String path, String bearerToken, int expectedStatus) {
      return send("POST", path, bearerToken, Map.of(), null, expectedStatus);
    }

    private ApiResponse delete(String path, String bearerToken, int expectedStatus) {
      return send("DELETE", path, bearerToken, Map.of(), null, expectedStatus);
    }

    private ApiResponse send(
        String method,
        String path,
        String bearerToken,
        Map<String, String> headers,
        JsonNode body,
        int expectedStatus) {
      return sendAbsolute(method, config.backendBaseUrl + path, bearerToken, headers, body, expectedStatus);
    }

    private ApiResponse sendAbsolute(
        String method,
        String absoluteUrl,
        String bearerToken,
        Map<String, String> headers,
        JsonNode body,
        int expectedStatus) {
      HttpRequest.Builder builder = HttpRequest.newBuilder()
          .uri(URI.create(absoluteUrl))
          .timeout(config.requestTimeout);
      if (bearerToken != null && !bearerToken.isBlank()) {
        builder.header("Authorization", "Bearer " + bearerToken);
      }
      if (headers != null) {
        for (Map.Entry<String, String> entry : headers.entrySet()) {
          builder.header(entry.getKey(), entry.getValue());
        }
      }
      if (body != null) {
        builder.header("Content-Type", "application/json");
        try {
          builder.method(method, HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body)));
        } catch (JsonProcessingException ex) {
          throw new RuntimeException("Failed to serialise JSON request body", ex);
        }
      } else {
        builder.method(method, HttpRequest.BodyPublishers.noBody());
      }
      try {
        HttpResponse<String> response = httpClient.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        return ApiResponse.fromResponse(method + " " + absoluteUrl, response, mapper, expectedStatus);
      } catch (IOException ex) {
        throw new UncheckedIOException("HTTP request failed for " + absoluteUrl, ex);
      } catch (InterruptedException ex) {
        Thread.currentThread().interrupt();
        throw new RuntimeException("HTTP request interrupted for " + absoluteUrl, ex);
      }
    }
  }

  private static final class ApiResponse {
    private final String requestLabel;
    private final int statusCode;
    private final String body;
    private final JsonNode json;
    private final String contentType;

    private ApiResponse(String requestLabel, int statusCode, String body, JsonNode json, String contentType) {
      this.requestLabel = requestLabel;
      this.statusCode = statusCode;
      this.body = body == null ? "" : body;
      this.json = json == null ? JsonNodeFactory.instance.nullNode() : json;
      this.contentType = contentType == null ? "" : contentType;
    }

    private static ApiResponse fromResponse(
        String requestLabel,
        HttpResponse<String> response,
        ObjectMapper mapper,
        int expectedStatus) {
      int actualStatus = response.statusCode();
      String body = response.body();
      if (actualStatus != expectedStatus) {
        throw new AssertionError(
            requestLabel
                + " expected HTTP "
                + expectedStatus
                + " but got "
                + actualStatus
                + ". Response body: "
                + (body == null || body.isBlank() ? "<empty>" : body));
      }
      JsonNode json = JsonNodeFactory.instance.nullNode();
      if (body != null && !body.isBlank()) {
        String trimmed = body.trim();
        String contentType = response.headers().firstValue("Content-Type").orElse("");
        if (contentType.contains("json") || trimmed.startsWith("{") || trimmed.startsWith("[")) {
          try {
            json = mapper.readTree(body);
          } catch (JsonProcessingException ex) {
            throw new AssertionError(
                requestLabel + " returned non-JSON content: " + body,
                ex);
          }
        }
      }
      String contentType = response.headers().firstValue("Content-Type").orElse("");
      return new ApiResponse(requestLabel, actualStatus, body, json, contentType);
    }

    private int statusCode() {
      return statusCode;
    }

    private String body() {
      return body;
    }

    private JsonNode json() {
      return json;
    }

    private String contentType() {
      return contentType;
    }
  }

  private static String form(Map<String, String> values) {
    StringBuilder builder = new StringBuilder();
    for (Map.Entry<String, String> entry : values.entrySet()) {
      if (builder.length() > 0) {
        builder.append('&');
      }
      builder.append(encodeQuery(entry.getKey()))
          .append('=')
          .append(encodeQuery(entry.getValue()));
    }
    return builder.toString();
  }

  private static String encodeQuery(String value) {
    return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
  }

  private static String encodePath(String value) {
    return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8).replace("+", "%20");
  }

  private static String firstNonBlank(String first, String second) {
    if (first != null && !first.isBlank()) {
      return first.trim();
    }
    return second;
  }

  private static long parseLongOrDefault(String raw, long fallback) {
    if (raw == null || raw.isBlank()) {
      return fallback;
    }
    try {
      long value = Long.parseLong(raw.trim());
      return value > 0 ? value : fallback;
    } catch (NumberFormatException ex) {
      return fallback;
    }
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
