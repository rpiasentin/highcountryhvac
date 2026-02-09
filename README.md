# High Country HVAC

This repo is the canonical Home Assistant configuration for the High Country hydronic HVAC system. It is the source of truth for production behavior. The POC repo (`homeassistantantigravity`) is treated as an objectives + design reference only.

## What This Release Is About
Dispatcher V2: translating the existing broadcast setpoints for Z1–Z9 into **optimized batch firing** to improve boiler efficiency. This release does **not** change how broadcast setpoints are computed (master/floor/room); it consumes those existing setpoints and manages zone inclusion.

## Where To Start
- Architecture and operating model: `docs/ARCHITECTURE.md`
- POC objectives + mode semantics: `docs/POC_OBJECTIVES.md`
- Implementation roadmap: `docs/IMPLEMENTATION_ROADMAP.md`
- Hydronic test procedure: `docs/HYDRONIC_TESTING.md`
- General test checklist: `docs/TEST_CHECKLIST.md`
- Access and test bridge: `docs/ACCESS.md`

## Current Status (As Of Feb 2026)
- Dispatcher V2 helpers, advisory logic, guardrails, and actuator are implemented.
- Manual caps override duration, min-run enforcement, and force-call logic are implemented.
- Testing is in progress; remaining focus is end-to-end stop/restore behavior and profile/opportunistic edge cases.

## Safety
Only one Home Assistant instance should control the system at any time. If staging is used, prod must be isolated or Hubitat must be retargeted.
