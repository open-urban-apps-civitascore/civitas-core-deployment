package de.civitascore.systemtests;

import com.fasterxml.jackson.databind.JsonNode;

public interface ResourceSupplier {
  JsonNode get();
}
