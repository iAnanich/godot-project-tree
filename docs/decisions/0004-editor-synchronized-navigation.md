# ADR 0004: Editor-synchronized navigation

Status: accepted for v0.2.0

## Decision

Use debounced editor filesystem notifications as the default refresh trigger, follow the active Script Editor file by default, and retain completion-based timed rescanning as a disabled fallback. Store the three options independently in editor-state schema v2.

## Rationale

Editor events reduce unnecessary scans and make the graph reflect saved project state quickly. Debouncing coalesces bursts. The scan-in-progress invariant and a pending flag prevent overlap or lost follow-up work. Self-generated export filesystem events are suppressed for a bounded period. Timed rescanning remains useful when external changes are not reported reliably.

## Consequences

The event path depends on editor notifications rather than file watchers. Unsaved buffer changes are not analyzed. Automatic exports can produce filesystem events, so the dock must suppress its own writes and still permit a later independent event.
