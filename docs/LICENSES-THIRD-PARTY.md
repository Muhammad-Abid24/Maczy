# Third-Party Open-Source License Audit & Attribution (MZ-025)

Maczy is released under the **MIT License**.  
All third-party open-source components used in Maczy are strictly governed by permissive open-source licenses (MIT, Apache 2.0, or BSD). No copyleft (GPL, AGPL, LGPL) software is included or linked.

---

## Rust Core Dependencies (`Cargo.lock`)

### 1. `serde` (v1.0.x)
- **License**: MIT OR Apache-2.0
- **Authors**: Erick Tryzelaar, David Tolnay
- **Repository**: https://github.com/serde-rs/serde
- **Usage**: Data serialization and deserialization for core state exchange.

### 2. `serde_derive` (v1.0.x)
- **License**: MIT OR Apache-2.0
- **Authors**: Erick Tryzelaar, David Tolnay
- **Repository**: https://github.com/serde-rs/serde
- **Usage**: Procedural derive macros for Serde.

### 3. `syn` (v2.0.x)
- **License**: MIT OR Apache-2.0
- **Authors**: David Tolnay
- **Repository**: https://github.com/dtolnay/syn
- **Usage**: Rust syntax parsing for derive macros.

### 4. `quote` (v1.0.x)
- **License**: MIT OR Apache-2.0
- **Authors**: David Tolnay
- **Repository**: https://github.com/dtolnay/quote
- **Usage**: Quasi-quoting Rust code generation.

### 5. `proc-macro2` (v1.0.x)
- **License**: MIT OR Apache-2.0
- **Authors**: David Tolnay, Alex Crichton
- **Repository**: https://github.com/dtolnay/proc-macro2
- **Usage**: Compiler token stream abstractions.

### 6. `unicode-ident` (v1.0.x)
- **License**: (MIT OR Apache-2.0) AND Unicode-DFS-2016
- **Authors**: David Tolnay
- **Repository**: https://github.com/dtolnay/unicode-ident
- **Usage**: Unicode identifier validation.

---

## Swift Dependencies

### 1. Sparkle 2 (MZ-027)
- **License**: MIT License
- **Copyright**: (c) 2006-2024 Andy Matuschak, Sparkle Project contributors.
- **Usage**: Secure, user-facing automatic software update distribution with Ed25519 signature verification.

---

## License Invariants
- **Zero GPL / AGPL / Copyleft**: The codebase is 100% free of copyleft encumbrances.
- **Redistributable**: Fully compliant with open-source community release and commercial bundling.
