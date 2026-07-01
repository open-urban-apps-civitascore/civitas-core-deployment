package de.civitascore.systemtests.keywords;

import com.fasterxml.jackson.databind.JsonNode;
import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.ResourceSupplier;
import java.time.Duration;
import java.util.Objects;

class KeywordAssertions {

  static String requiredText(JsonNode node, String field, String label) {
    String value = textOrNull(node, field);
    if (value == null || value.isBlank()) {
      throw new AssertionError(label + " must be present. Response: " + node.toPrettyString());
    }
    return value;
  }

  static String textOrNull(JsonNode node, String field) {
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

  static void assertTextEquals(String expected, String actual) {
    if (!Objects.equals(expected, actual)) {
      throw new AssertionError("Expected '" + expected + "' but got '" + actual + "'");
    }
  }

  static void assertNullOrEmpty(String value, String message) {
    if (value != null && !value.isBlank()) {
      throw new AssertionError(message + ": " + value);
    }
  }

  static void assertTrue(boolean condition, String message) {
    if (!condition) {
      throw new AssertionError(message);
    }
  }

  static void assertBooleanEquals(boolean expected, boolean actual, String label) {
    if (expected != actual) {
      throw new AssertionError(label + " expected '" + expected + "' but got '" + actual + "'");
    }
  }

  static void assertIsArray(JsonNode node, String label) {
    assertTrue(node.isArray(), label + " must be a JSON array");
  }

  static void assertIsObject(JsonNode node, String label) {
    assertTrue(node.isObject(), label + " must be a JSON object");
  }

  static void assertArrayContainsText(JsonNode arrayNode, String expectedValue, String label) {
    assertTrue(arrayNode.isArray(), label + " must be an array");
    for (JsonNode node : arrayNode) {
      if (Objects.equals(expectedValue, node.asText())) {
        return;
      }
    }
    throw new AssertionError(label + " must contain '" + expectedValue + "'. Response: " + arrayNode.toPrettyString());
  }

  static void assertArrayContainsObjectWithId(JsonNode arrayNode, String expectedId, String label) {
    assertTrue(arrayNode.isArray(), label + " must be an array");
    for (JsonNode node : arrayNode) {
      if (Objects.equals(expectedId, node.path("id").asText(null))) {
        return;
      }
    }
    throw new AssertionError(label + " must contain an object with id '" + expectedId + "'. Response: " + arrayNode.toPrettyString());
  }

  static JsonNode responseJsonOrFetch(ApiResponse response, ResourceSupplier fallback, String operationLabel) {
    if (!response.json().isNull() && !response.json().isMissingNode()) {
      return response.json();
    }
    JsonNode fallbackJson = fallback.get();
    assertTrue(
        fallbackJson != null && !fallbackJson.isNull() && !fallbackJson.isMissingNode(),
        operationLabel + " must provide a JSON response or a readable follow-up resource");
    return fallbackJson;
  }

  static void sleep(Duration duration) {
    try {
      Thread.sleep(duration.toMillis());
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new RuntimeException("Interrupted while waiting", ex);
    }
  }

  static JsonNode waitForResourceStatus(
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

  private KeywordAssertions() {}
}
