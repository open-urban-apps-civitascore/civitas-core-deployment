package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.SystemTestState;
import de.civitascore.systemtests.TestContext;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.util.Map;
import java.util.Objects;
import org.robotframework.javalib.annotation.ArgumentNames;
import org.robotframework.javalib.annotation.RobotKeyword;
import org.robotframework.javalib.annotation.RobotKeywords;

import static de.civitascore.systemtests.keywords.KeywordAssertions.*;

@RobotKeywords
public class GatewayKeywords {

  private final SystemTestState state = TestContext.state();
  private final ObjectMapper mapper = TestContext.mapper();
  private final PortalBackendClient portalClient = TestContext.portalClient();

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

  @RobotKeyword("Verify Gateway Access")
  @ArgumentNames({"expectedStatus=200", "withAuthentication=false"})
  public void verifyGatewayAccess(String expectedStatus, String withAuthentication) {
    ensureNamedApiPreviewUrl();
    int status = KeywordUtils.parsePositiveInt(expectedStatus, 200);
    boolean authenticated = KeywordUtils.parseBoolean(withAuthentication);
    String bearerToken = authenticated ? state.accessToken : null;
    ApiResponse response = portalClient.getText(state.namedApiPreviewUrl, bearerToken, Map.of(), status);
    if (status == 200) {
      assertTrue(!response.body().isBlank(), "Gateway response body must not be empty");
      assertTrue(response.contentType().contains("json") || response.body().trim().startsWith("{")
          || response.body().trim().startsWith("["), "Gateway response should be JSON");
    }
  }

  @RobotKeyword("Verify Gateway Response Content")
  @ArgumentNames({"expectedThingName=", "expectedDescription="})
  public void verifyGatewayResponseContent(String expectedThingName, String expectedDescription) {
    ensureNamedApiPreviewUrl();
    String bearerToken = state.openDataAccess ? null : state.accessToken;
    ApiResponse response = portalClient.getText(state.namedApiPreviewUrl, bearerToken, Map.of(), 200);
    assertGatewayResponseContainsExpectedThing(
        response.json(),
        KeywordUtils.firstNonBlank(expectedThingName, state.expectedGatewayThingName),
        KeywordUtils.firstNonBlank(expectedDescription, state.expectedGatewayThingDescription));
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

  private void ensureInitialized() {
    if (state.runSuffix == null || state.runSuffix.isBlank()) {
      throw new IllegalStateException("System test run has not been initialized");
    }
  }

  private void ensureNamedApiPreviewUrl() {
    ensureInitialized();
    if (state.namedApiPreviewUrl == null || state.namedApiPreviewUrl.isBlank()) {
      throw new IllegalStateException("Named API preview URL is not available yet");
    }
  }
}
