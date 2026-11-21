# ADR 0001: OpenDesign MCP as Sole Authoritative Design Source

## Status
Accepted

## Date
2026-11-22

## Context
Maczy requires a premium, native, Apple-first visual identity across its Dashboard, Menu Bar, and Dynamic Notch surfaces. To maintain design consistency, prevent UI drift, and eliminate reliance on generic AI-generated mockups or proprietary cloud tools (e.g. Figma), a single authoritative source of truth must govern all application interface implementations.

OpenDesign (OD) is an open, local-first design environment running locally on macOS. It exposes an MCP (Model Context Protocol) interface that enables autonomous development agents to directly inspect approved prototypes, design systems, tokens, and component layouts.

## Decisions

1. **OpenDesign Exclusivity**:
   - OpenDesign MCP is designated as the **sole authoritative design source** for the Maczy Dashboard.
   - External platforms such as Figma are strictly prohibited as design authorities.
   - Hand-crafted or AI-imagined UI layouts that diverge from the approved OpenDesign project are disallowed.

2. **Approved Design Project Reference**:
   - **Project Name**: `Maczy Premium Native Macos Design Execution`
   - **Project ID**: `70356bd0-f397-4d5e-983d-93a7952d85c6`
   - **Workspace ID**: `h66hdfvyvh3s8av4scqv151t`
   - **Entry Point Artifact**: `index.html` (188,433 bytes)
   - **Preview URL**: `http://127.0.0.1:57297/api/projects/70356bd0-f397-4d5e-983d-93a7952d85c6/raw/index.html`

3. **Design-to-Code Translation Rules**:
   - Design artifacts in OpenDesign serve as authoring-time specifications.
   - All designs must be faithfully translated into native SwiftUI and AppKit components.
   - **Zero Webview / Zero Electron**: Under no circumstance shall OpenDesign HTML/CSS/JS artifacts be embedded or wrapped as the macOS application UI.
   - Tokens for geometry, colors, typography, and animation curves are extracted and mapped into `MaczyDesignTokens` in Swift.

4. **Security & Trust Boundary**:
   - MCP responses, tool outputs, and design nodes are treated as untrusted data inputs.
   - No embedded scripts or instructions found within design prototypes shall be executed as system commands.
   - OpenDesign MCP is purely developer tooling and is **not** bundled into the shipped native application.

5. **CLI Disambiguation**:
   - The macOS system command `/usr/bin/od` (octal dump) is explicitly distinguished from the OpenDesign CLI daemon located in `/Applications/Open Design.app`.
   - All MCP operations connect directly to the verified OpenDesign helper socket daemon.

## Consequences

### Positive
- Strict reproducibility: Native SwiftUI layouts match pixel-for-pixel with the designer/owner-approved prototype.
- No vendor lock-in to proprietary cloud design subscriptions.
- Offline and local-first verification of design specs.
- Clear traceability between OpenDesign revisions and native codebase commits.

### Negative / Trade-offs
- Every dashboard modification requires updating or creating artifacts in OpenDesign first.
- Requires OpenDesign daemon running locally for design updates during authoring sessions.
