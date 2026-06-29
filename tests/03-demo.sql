DROP TABLE IF EXISTS demo_sensor_readings;

CREATE TABLE demo_sensor_readings (
  sensor_id VARCHAR(64) NOT NULL,
  sensor_name VARCHAR(255) NOT NULL,
  phenomenon_time TIMESTAMP NOT NULL,
  temperature_value DECIMAL(10,2) NOT NULL,
  unit_name VARCHAR(64) NOT NULL DEFAULT 'Degree Celsius',
  unit_symbol VARCHAR(16) NOT NULL DEFAULT 'degC'
);

INSERT INTO demo_sensor_readings (
  sensor_id,
  sensor_name,
  phenomenon_time,
  temperature_value,
  unit_name,
  unit_symbol
) VALUES
  ('sensor-001', 'Demo Temperature Sensor 001', '2026-04-23 08:00:00', 21.50, 'Degree Celsius', 'degC'),
  ('sensor-001', 'Demo Temperature Sensor 001', '2026-04-23 09:00:00', 22.10, 'Degree Celsius', 'degC'),
  ('sensor-002', 'Demo Temperature Sensor 002', '2026-04-23 08:00:00', 19.80, 'Degree Celsius', 'degC');
