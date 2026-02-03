# POC vs Canonical Comparison

This compares the POC repo (`homeassistantantigravity`) to the canonical config.

## packages
POC files: 5
Canonical files: 27

### Only in POC
- hc_dispatcher_actuator.yaml
- hc_dispatcher_v2_cluster_stats.yaml
- hc_dispatcher_v2_helpers.yaml
- hc_dispatcher_v2_zone_lengths.yaml

### Only in Canonical
- hc_analytics_proxies.yaml
- hc_cold_tolerance_control.yaml
- hc_cold_tolerance_gate.bak_20260111_211059
- hc_cold_tolerance_gate.yaml
- hc_dispatcher_broadcast_follow.yaml
- hc_dispatcher_inputs.yaml
- hc_hydronic_kick.bak_20260111_211113
- hc_hydronic_kick.yaml
- hc_influxdb.yaml
- hc_minisplit_sync_missing.yaml
- hc_observability_coincident_heat.yaml
- hc_outdoor_delta_advisory.yaml
- hc_zone4_garage_thermostat.yaml
- hc_zone_delta_sensors.bak_20260111_211046
- hc_zone_delta_sensors.yaml
- high_country_call_for_heat.yaml
- high_country_call_for_heat.yaml.bak_2026-01-11_211825
- high_country_minisplit_sync.yaml
- high_country_sanity.yaml
- high_country_setpoint_automations.yaml
- high_country_setpoint_automations.yaml.bak_2026-01-11_212233
- high_country_setpoints.bak_20260111_211028
- high_country_setpoints.yaml
- high_country_setpoints.yaml.bak_2026-01-10_221031
- high_country_setpoints.yaml.bak_2026-01-11_212233
- high_country_upstairs_avg_temp.yaml

### In Both, Different Content
- hc_dispatcher_advisory.yaml

### In Both, Same Content
- (none)

## lovelace
POC files: 1
Canonical files: 2

### Only in POC
- hc_zone_setup.yaml

### Only in Canonical
- hc_hydronic_test.yaml
- hc_hydronic_test.yaml.bak_20260117_191425

### In Both, Different Content
- (none)

### In Both, Same Content
- (none)
