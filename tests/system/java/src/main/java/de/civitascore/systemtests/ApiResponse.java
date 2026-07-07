package de.civitascore.systemtests;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import java.net.http.HttpResponse;

public class ApiResponse {
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

  public static ApiResponse fromResponse(
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

  public int statusCode() {
    return statusCode;
  }

  public String body() {
    return body;
  }

  public JsonNode json() {
    return json;
  }

  public String contentType() {
    return contentType;
  }
}
