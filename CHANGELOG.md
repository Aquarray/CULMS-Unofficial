# Changelog

All notable changes to the **CU-LMS Unofficial** application are documented in this file.

---

## [1.1.4] - 2026-11-24

### Added
- **File Extension & Signature Analysis Service (`FileExtensionService`)**:
  - Positioned directly between downloading bytes and saving files.
  - Analyzes binary headers and magic bytes to guarantee accurate file extensions before writing to cache or disk.
  - Signature detection for common types:
    - `pdf`: `%PDF-` magic header (`0x25 0x50 0x44 0x46`).
    - `docx`: PK Zip header containing internal OpenXML Word structures (`word/document.xml`, `wordprocessingml`).
    - `pptx`: PK Zip header containing internal OpenXML PowerPoint structures (`ppt/presentation.xml`, `presentationml`).
    - `zip`: Generic PK Zip archives without Office OpenXML structures.
  - Automatically fixes mismatched or extensionless files (e.g., Moodle OfficeViewer converted PDF streams named `.pptx` or generic `download.php` URLs).
  - Integrated into `ZipExportService`, `CacheService`, `PdfViewerScreen`, and `LmsApiClient`.

- **PDF24 Merged PDF Export Pipeline (`Pdf24Service`)**:
  - Added a new export format option: **Merged PDF** alongside packed **ZIP** and **Folder** exports.
  - Automated PDF24 worker pipeline: multipart file upload, `joinPdf` merge job initiation, job status polling, token generation, and PDF result streaming with `%PDF-` verification.
  - **ZIP Extraction**: Automatically unpacks and extracts contents of any ZIP files within the unit to include their individual documents in the merge.
  - **Unknown File Filtering**: Strictly filters out unsupported binary formats, scripts, HTML error pages, and OS metadata files (`__MACOSX`, `.DS_Store`). Only valid documents (PDF, PPTX, DOCX, PPT, DOC, TXT, MD, images) are merged.
  - **Abuse Prevention & Transaction-Based Rate Limiting**:
    - Rate limit enforced at **10 transactions / 10 merged PDFs per 2-hour window** (instead of per-file), so entire multi-file units count as a single merge operation.
    - **Unlimited Mode ($\infty$)**: Rate limit can be set to infinity using a master password whose SHA-256 hash is verified securely within the app (plaintext password is never stored).
    - Added an informative rate limit notice in the Unit Export Sheet.
    - Added a live **PDF24 Quota & Rate Limit** card in **Export & AI Tools Settings** displaying remaining merges, used count, unlock countdown timers, and an "Unlock Unlimited (∞)" dialog or "Re-enable Rate Limit" toggle.

---

## [1.1.3] - 2026-11-15

### Fixed
- **Isolate Scope & Unsendable Object Deadlock**:
  - Extracted isolate workers in `LmsApiClient` into static methods (`_parseCourseFormatStateInIsolate`, `_parseCoursesInIsolate`, etc.) taking only primitive parameters.
  - Resolved `Invalid argument(s): Illegal argument in isolate message: object is unsendable - Class: _Future` caused by lexical scope closures capturing `LmsApiClient` and `CacheService._pending`.
  - Removed unnecessary isolate overhead on already-cached in-memory mappings.

---

## [1.1.2] - 2026-11-15

### Fixed
- Fixed LMS sub-chapters (1.2, 1.3, etc.) disappearing by parsing topics dropdown and refining empty unit header filters.
- Fixed Moodle course format state parsing for string numbers in section lists.
- Fixed missing `Material` ancestor assertion for `ListTile` widgets.
- Fixed UI deadlock and touch freeze on detail route pop.
- Added **"Disable Animations"** accessibility toggle in Settings.

---

## [1.1.1] - 2026-10-15

### Added
- HTML reading service and parser for lesson pages.
- Native reading view support for LMS reading materials.

---

## [1.1.0] - 2026-10-14

### Added
- Study with AI prompt generation for Gemini and ChatGPT.
- Local alarms and push notifications for assignment deadlines.
- Quiz AI assistant support with model discovery.

