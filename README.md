# 🎓 CUIMS Mobile (Unofficial) — Chandigarh University LMS Portal

<p align="center">
  <img src="assets/images/app_icon.png" alt="CUIMS LMS Logo" width="160" height="160" style="border-radius: 32px; box-shadow: 0 8px 24px rgba(211, 47, 47, 0.25);" />
</p>

<p align="center">
  <strong>A modern, high-performance, and feature-rich mobile client for Chandigarh University's Learning Management System (CUIMS / Moodle).</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/State_Management-Riverpod_3-purple" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Linux%20%7C%20Web-success" alt="Platforms" />
  <img src="https://img.shields.io/badge/Tests-49%20Passed-brightgreen" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License" />
</p>

---

## 📌 Table of Contents
1. [Overview & Project Purpose](#-overview--project-purpose)
2. [Visual Identity & App Icon](#-visual-identity--app-icon)
3. [Complete Feature Showcase](#-complete-feature-showcase)
   - [Cloud SSO & Session Engine](#1-cloud-sso--session-engine)
   - [Academic Dashboard](#2-academic-dashboard)
   - [Dual-Course Syllabus & Material Hub](#3-dual-course-syllabus--material-hub)
   - [Assignment Hub & In-App Submissions](#4-assignment-hub--in-app-submissions)
   - [Medium-Style Reading & Text-to-Speech](#5-medium-style-reading--text-to-speech)
   - [Unit ZIP Exporter & Learn with AI](#6-unit-zip-exporter--learn-with-ai)
   - [AI Quiz Assistant & In-App Browser](#7-ai-quiz-assistant--distraction-free-in-app-browser)
   - [Deadline Alarms & Local Notifications](#8-deadline-alarms--local-notifications)
   - [Offline Caching & Developer Diagnostics](#9-offline-caching--developer-diagnostics)
4. [Architecture & State Management](#-architecture--state-management)
5. [Project Structure](#-project-structure)
6. [Prerequisites & Setup Guide](#-prerequisites--setup-guide)
7. [Running & Testing](#-running--testing)
8. [Engineering Review & Flagged Uncertainties](#-engineering-review--flagged-uncertainties)

---

## 📖 Overview & Project Purpose

The official Chandigarh University Learning Management System (Moodle) portal is primarily designed for desktop browsers. On mobile devices, students often encounter:
- Cumbersome SSO authentication barriers with complex redirects and OCR captchas.
- Cluttered desktop web interfaces with redundant navigation menus and tiny touch targets.
- Disconnected course spaces (separation of study notes `CONT_...` from testing modules `25CSH-...`).
- Inability to quickly read documents offline or download entire units without clicking dozens of nested links.
- Missed assignment and quiz submission deadlines due to lack of native device alarms.

**CUIMS Mobile (Unofficial)** solves these challenges by acting as a native companion app. It routes university student credentials through a dedicated serverless SSO gateway, manages real Moodle session cookies and security tokens (`sesskey`), directly queries Moodle 4/5 AJAX endpoints, and provides a polished Material 3 experience with offline caching, document readers, assignment submission management, and AI-assisted study tools.

---

## 🎨 Visual Identity & App Icon

The application's emblem is based on Chandigarh University's academic branding, featuring the **Continuous Learning Cycle**:
- **Mortarboard / Graduation Cap**: The central focus of academic achievement and student success.
- **Continuous Circular Arrows**: Seamless progression through course units, practicals, and assessments.
- **Three Knowledge Nodes with Sparkles**: Mastery of Theory, Practical Lab Work, and Continuous Evaluation.
- **Brand Crimson Red (`#D32F2F` / `#C62828`)**: Chandigarh University's signature color.

### Asset Locations
- Master Icon (1024×1024): [`assets/images/app_icon.png`](assets/images/app_icon.png)
- Master Transparent Glyph: [`assets/images/app_icon_red_glyph.png`](assets/images/app_icon_red_glyph.png)
- Android Adaptive Icons: `android/app/src/main/res/mipmap-*/` (`ic_launcher.png`, `ic_launcher_round.png`, `ic_launcher_foreground.png`, `ic_launcher_background.png`)
- Web Icons: `web/icons/Icon-192.png`, `web/icons/Icon-512.png`, `web/favicon.png`

---

## 🚀 Complete Feature Showcase

### 1. Cloud SSO & Session Engine
- **Serverless SSO Gateway**: Sends user credentials to a Vercel serverless proxy (`https://lmssso.vercel.app/api/sso`) using Bearer token authentication.
- **Graceful Delay Handling**: Accommodates the serverless gateway's 5-second processing window with real-time status feedback.
- **Manual Captcha Fallback**: If gateway OCR fails or triggers a captcha challenge, a native `CaptchaDialog` displays the base64 image challenge for student input.
- **Cookie & Token Capture**: Intercepts Moodle autologin redirects, persists the authenticated `MoodleSession` cookie, and extracts the dynamic `sesskey` required for all Moodle AJAX operations.
- **Session Validation & Auto-Login**: Validates saved sessions on application launch and automatically redirects to the dashboard if still active.

### 2. Academic Dashboard
- **Academic Statistics**: Real-time metrics tracking enrolled courses, in-progress courses, and pending deadlines.
- **Upcoming Timeline Events**: Fetches scheduled quizzes, assignments, and test deadlines via Moodle's `core_calendar_get_action_events_by_timesort`.
- **Urgency Indicators**: Color-coded badges indicating overdue tasks, items due today, and upcoming deadlines with countdowns.
- **Quick Resume Carousel**: Horizontally scrolling cards for recently accessed courses featuring staggered slide animations (`SlideScrollItem`).
- **Notification Permission Banner**: Startup prompt requesting notification permissions with contextual explanation.

### 3. Dual-Course Syllabus & Material Hub
- **Dual-Course Architecture**: Automatically detects and links companion courses between Study Content (`CONT_...`) and Assessment / Test courses (`25CSH-...`).
- **1-Tap Companion Switcher**: Switch between a subject's lecture notes and its corresponding quizzes/tests without searching the catalog.
- **Moodle 4/5 AJAX Tree Parsing**: Direct integration with `core_courseformat_get_state` to parse course structures in under 350ms.
- **Smart Category Filtering**: Dynamic tabs that adapt to each course:
  - 📖 **Theory**: Filtered lecture units and chapter folders.
  - 🧪 **Practical**: Lab experiments, code files, and manual sheets.
  - 📋 **Assessment Model**: Weightage breakdowns and course outlines.
  - 📹 **Live Session Links**: Direct Zoom / Google Meet / MS Teams join actions.
  - ⚡ **Surprise Tests & Quizzes**: Direct links to online assessments.
  - 📑 **Assignments**: Coursework submissions and problem sets.
- **Sub-Unit Hierarchy**: Groups materials into `Unit 1`, `Unit 2`, `Chapter 1.1`, `Chapter 1.2` while hiding empty template sections.

### 4. Assignment Hub & In-App Submissions
- **Complete Assignment Details**: Scrapes deadline dates, remaining time, submission status (Submitted, Draft, Overdue), grading status, and rubric files.
- **Native File Picker**: Allows selecting PDF, Word, ZIP, and code files from device storage.
- **Moodle Draft File Area Upload**: Communicates directly with Moodle's `/repository/repository_ajax.php?action=upload` to stage draft files.
- **Draft Management**: View and delete staged draft files with live status updates.
- **Final Submission Lock**: Locks final submission via `mod_assign_save_submission` directly within the app.

### 5. Medium-Style Reading & Text-to-Speech
- **In-App PDF Viewer**: Powered by `pdfrx` with pinch-to-zoom, page thumbnails, page jumper, color inversion (night mode), and native file sharing via `share_plus`.
- **Editorial Markdown Viewer**: Clean typography with support for LaTeX formulas, tables, and code snippets.
- **High-Contrast Reading Themes**:
  - 📜 *Warm Sepia* (Medium-style comfort reading)
  - ☀️ *Clean Light*
  - 🌙 *Soft Dark*
  - ⬛ *OLED Black* (Pure `#000000` AMOLED power-saving mode)
  - 🌲 *Forest Mist* (Calming green tint)
- **Customizable Typography**: Switch between *Inter*, *Plus Jakarta Sans*, *Roboto*, *Literata*, or *System Default*.
- **Integrated Text-to-Speech (TTS)**: Built-in voice synthesizer (`flutter_tts`) that narrates lecture notes aloud with adjustable speech rate, pitch, and playback controls.

### 6. Unit ZIP Exporter & "Learn with AI"
- **Batch Unit Exporter**: Downloads all documents (PPTX, PDF, DOCX, TXT) within an entire course unit and packages them into an on-the-fly `.zip` archive using `archive`.
- **Native System Sharing**: Exports ZIP files to external storage, WhatsApp, Telegram, or Google Drive via `share_plus`.
- **"Learn with AI" Prompt Generator**:
  - Generates a structured study prompt specifying source priorities (`DOCX > PPT > TXT`).
  - Pre-populates the university subject and unit title.
  - Copies the prompt to clipboard and opens Google Gemini or ChatGPT in one tap, ready for the user to attach the downloaded unit ZIP.

### 7. AI Quiz Assistant & Distraction-Free In-App Browser
- **Session-Synchronized In-App Browser**: `AppBrowserScreen` embeds WebView with injected `MoodleSession` cookies to access any LMS link without logging in again.
- **Clean Mode CSS/JS**: Strips away header navigation, sidebars, and footers, leaving only the quiz questions.
- **AI Quiz Helper (`QuizAiService`)**:
  - Automatically parses Moodle question containers (`.que.multichoice`, `.qtext`, `.answer div.r0/r1`, `input[type="radio"]`).
  - Sends question context to either **Google Gemini** (`gemini-1.5-flash`, etc.) or **OpenAI** (`gpt-4o-mini`, etc.).
  - Visually highlights recommended options with explanations in an inline badge.
  - **Academic Safety Policy**: Strictly designed as a study aid — marks recommended options and explains reasoning, but **never automatically submits or advances** the quiz attempt.
- **Live AI Model Discovery**: Queries AI provider APIs (`GET /v1beta/models` for Gemini, `GET /v1/models` for OpenAI) to populate active models dynamically.
- **Automated AI Response Tester**: Interactive test dialog that runs a predefined math question to verify API connectivity and response quality.
- **Anti-Accidental Exit Guard**: Warns students before closing or navigating away from an ongoing quiz attempt.

### 8. Deadline Alarms & Local Notifications
- **Scheduled Alarms**: Uses `flutter_local_notifications` and `timezone` to schedule precise local notifications for upcoming quiz and assignment deadlines.
- **Customizable Advance Notice**: Configurable reminders (1 hour, 3 hours, 6 hours, 12 hours, or 24 hours before deadline).
- **Background Persistence**: Alarms trigger independently even if the app is closed.

### 9. Offline Caching & Developer Diagnostics
- **Two-Tier Cache Engine**:
  - Level 1: In-memory cache for instant navigation.
  - Level 2: Local disk cache (`CacheService`) storing course catalogs, unit hierarchies, and downloaded PDFs with configurable TTL (default: 12 hours).
- **Cache Management**: Real-time cache size calculation and 1-tap cache clear in Settings.
- **Live Debug Console (`DebugLogsScreen`)**: Real-time in-app HTTP/INFO/ERROR inspector with tag filtering, search, and clipboard export.
- **Quick Diagnostics**: Built-in triggers to test SSO Gateway ping, Course List fetch, and Calendar Event fetch.
- **CLI Test Script (`bin/test_fetch.dart`)**: Standalone terminal tool for developers to test Moodle AJAX endpoints and session cookies without launching Flutter UI.

---

## 🏛 Architecture & State Management

The application is built on **Modular Clean Architecture** principles and powered by **Riverpod 3** (`Notifier` and `NotifierProvider`).

```
lib/
├── core/                       # Foundation Services & Application Config
│   ├── config/                 # Global constants, URLs, timeouts
│   ├── services/               # Singletons: Cookie, Cache, Alarm, TTS, ZIP, Log, AI
│   └── theme/                  # App theme, reading themes, dynamic color seeds
├── data/                       # Data & Network Layer
│   ├── models/                 # Pure Dart models with JSON serialization
│   └── network/                # LmsApiClient (SSO, Moodle AJAX, Scrapers)
├── providers/                  # Riverpod 3 State Management
│   ├── auth_provider.dart      # AuthState state machine & credentials
│   ├── course_provider.dart    # Courses catalog, search, and category filters
│   ├── dashboard_provider.dart # Academic metrics and calendar events
│   ├── assignment_provider.dart# Assignment details & submission config
│   ├── settings_provider.dart  # App settings & preferences with persistence
│   └── app_providers.dart      # Global provider registry & dependency injection
└── ui/                         # Presentation Layer
    ├── common/                 # Reusable widgets (Nav bar, Banners, Animations)
    └── screens/                # Feature screens (Auth, Dashboard, Courses, Reader, Quiz, Settings)
```

### State Management Highlights
| Provider | Type | Role |
| :--- | :--- | :--- |
| `settingsProvider` | `Notifier<AppSettings>` | Manages theme mode, typography, reading contrast, AI API keys, and SSO gateway overrides with `SharedPreferences` persistence. |
| `authProvider` | `Notifier<AuthState>` | Reactive state machine (`initial` ➔ `connectingGateway` ➔ `captchaRequired` ➔ `loggingInMoodle` ➔ `authenticated`). |
| `coursesProvider` | `Notifier<CourseListState>` | Manages enrolled courses, search query filtering, and category selection. |
| `dashboardProvider` | `Notifier<DashboardState>` | Fetches and manages timeline deadlines, stats, and course shortcuts. |
| `assignmentDetailProvider` | `FutureProvider.family` | Fetches and caches individual assignment details and submission status. |
| `ttsProvider` | `Notifier<TtsState>` | Controls audio narration state (playing, paused, progress, word position). |

---

## 📂 Project Structure

```
cuims_unofficial2/
├── android/                    # Android native configuration & launcher icons
├── assets/
│   └── images/                 # App icon master glyphs and assets
├── bin/
│   └── test_fetch.dart         # Standalone CLI testing script
├── lib/                        # Flutter Dart source code (Clean Architecture)
├── test/                       # 49 unit and widget tests
│   ├── fixtures/               # Real Moodle quiz DOM test fixtures
│   ├── ai_study_prompt_sheet_test.dart
│   ├── auth_autologin_test.dart
│   ├── custom_bottom_nav_test.dart
│   ├── models_and_cache_test.dart
│   ├── quiz_ai_test.dart
│   ├── slide_scroll_item_test.dart
│   ├── widget_test.dart
│   └── zip_export_service_test.dart
├── Progress.md                 # Detailed implementation milestone tracker
├── course_inside.md            # Technical analysis of Moodle AJAX endpoints
└── pubspec.yaml                # Project dependencies and asset definitions
```

---

## ⚙️ Prerequisites & Setup Guide

### 1. Prerequisites
- **Flutter SDK**: `>= 3.47.0` (Dart SDK `>= 3.13.4`)
- **Android Studio / Android SDK**: Platform API 34+
- **Linux Build Tools** (if building for Linux desktop): `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- **Git**

### 2. Clone and Install Dependencies
```bash
git clone https://github.com/<your-repo>/cuims_unofficial2.git
cd cuims_unofficial2
flutter pub get
```

### 3. Key Dependencies
- **Networking & State**: `dio`, `cookie_jar`, `dio_cookie_manager`, `flutter_riverpod`
- **File Handling & Storage**: `archive`, `path_provider`, `shared_preferences`, `file_picker`, `share_plus`
- **Document Viewing**: `pdfrx` (PDF rendering), `flutter_markdown` (Markdown notes)
- **Audio & Notifications**: `flutter_tts` (Text-To-Speech), `flutter_local_notifications`, `timezone`
- **In-App Browser**: `webview_flutter`
- **UI & Typography**: `google_fonts`, `cupertino_icons`

---

## 🧪 Running & Testing

### Run on Connected Device / Emulator
```bash
# Run on Android
flutter run -d android

# Run on Linux Desktop
flutter run -d linux

# Run on Chrome
flutter run -d chrome
```

### Execute Test Suite
The codebase includes 49 automated unit, widget, and DOM parsing tests:
```bash
flutter test
```

### Terminal CLI Diagnostic Tool
You can test Moodle session authentication and endpoint scraping directly from your terminal without opening the Flutter UI:
```bash
# Using saved session or interactive login:
dart run bin/test_fetch.dart

# Or pass specific session cookies:
dart run bin/test_fetch.dart --session <MoodleSessionCookie> --sesskey <sesskey>
```

---

## ⚠️ Engineering Review & Flagged Uncertainties

During analysis of this codebase, the following items were identified for awareness and ongoing maintenance:

1. **Vercel Serverless SSO Gateway Dependency**:
   - The initial authentication stage relies on `https://lmssso.vercel.app/api/sso` with a default Bearer token (`dont_use_please`).
   - If the Vercel deployment experience rate limits, cold-start timeouts (>40s), or is taken offline, users will not be able to authenticate unless they configure a custom endpoint in **Settings -> SSO Gateway Configuration**.
2. **Moodle Web & AJAX DOM Selectors**:
   - Features like the Assignment Details Scraper, File Uploader, and AI Quiz Assistant parse specific Moodle HTML class names (`.que.multichoice`, `.qtext`, `.generaltable`, etc.).
   - If Chandigarh University updates Moodle core or adopts a substantially different custom web theme, these DOM selectors may need maintenance.
3. **Moodle Session Lifespan**:
   - Moodle server sessions typically expire after 2–4 hours of inactivity. The app includes session validation on launch, but active sessions may occasionally require re-authentication if left idle for extended periods.
4. **Third-Party AI API Keys**:
   - The Quiz AI Assistant requires a personal Google Gemini API key or OpenAI API key entered by the user in Settings. No keys are hardcoded in the codebase.
5. **iOS Native Setup**:
   - The codebase has been verified on Android and Linux desktop. For iOS builds, notification permissions and `pdfrx` native framework dependencies must be configured in `ios/Runner/Info.plist` and CocoaPods.

---

<p align="center">
  Built with ❤️ for Chandigarh University Students.
</p>