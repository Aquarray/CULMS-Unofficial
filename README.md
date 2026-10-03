Flutter LMS Mobile App - Technical Plan

1. Project Overview

App Objective: Redesign of the LMS portal for mobile users.

Framework: Flutter (chosen for highly efficient performance and superior UI capabilities).

Core Challenge: Direct LMS login is restricted. Authentication requires routing through a custom Vercel serverless backend to handle university SSO, retrieve session tokens, and bypass complex auto-login barriers.

2. Technical Authentication Flow (SSO)

API Configuration

Gateway Endpoint: POST https://lmssso.vercel.app/api/sso

Headers:

Content-Type: application/json

Authorization: Bearer <API_TOKEN>

Step 2.1: Initial Login Payload

The Flutter app will send the user's credentials to the Vercel gateway.

{
  "uid": "<SAMPLEUID>", 
  "password": "<SAMPLEPAS>"
}



Step 2.2: State & Response Handling

State 0: Processing & Delay Handling

Display a loading state: "Connecting to Cloud SSO Gateway..."

Important Constraint: The login process may take time. Implement a 5-second wait/delay handling mechanism to gracefully accommodate the gateway's processing time without timing out the UI.

State 1: Direct Success (Auto-verified)

Condition: HTTP Status OK & JSON response contains "success": true and "lmsLoginUrl": "<URL>".

Action:

Update UI state: "LMS SSO Authorization Successful! Redirecting..."

Navigate the app (likely via a headless WebView or HTTP client) to the provided Moodle autologin URL.

Extract and store the resulting Moodle session cookies (e.g., MoodleSession) and the sesskey for all subsequent data fetching.

State 2: Manual Captcha Required (OCR Failure)

Condition: JSON response contains "success": false and "requireManualCaptcha": true.

Action: Pause login, store "sessionToken", and show "captchaImage" (base64) to the user for manual entry.

State 3: Captcha Submission

Send follow-up POST with uid, password, captcha, and sessionToken. Handle success/failure as above.

State 4: Explicit Failure

Handle network or credential errors by showing an error dialog.

3. Cookie & Session Management

Implement a Cookie Manager (e.g., using dio_cookie_manager).

Captured Moodle session cookies and the extracted sesskey MUST be injected into the headers/URLs of all subsequent API calls to fetch Moodle data.

4. UI Navigation & Layout

The application will utilize a custom Bottom Navigation Bar for core routing:

Left Icon: MyCourses

Center Action: Dashboard (Floating Action Button style, prominent in the center)

Right Icon: Settings

5. Dashboard Data Fetching (Moodle AJAX)

Once authenticated, the app will hit the standard Moodle AJAX service endpoints. Note: The sesskey extracted during the login phase must be appended to the query parameters.

5.1 Fetching Enrolled Courses

Endpoint: POST https://lms.cuchd.in/lib/ajax/service.php?sesskey=<sesskey>&info=core_course_get_enrolled_courses_by_timeline_classification

Headers: Includes Moodle Session cookies.

Payload:

[
    {
        "index": 0,
        "methodname": "core_course_get_enrolled_courses_by_timeline_classification",
        "args": {
            "offset": 0,
            "limit": 30,
            "classification": "all",
            "sort": "fullname",
            "customfieldname": "",
            "customfieldvalue": "",
            "requiredfields": [
                "id",
                "fullname",
                "shortname",
                "showcoursecategory",
                "visible",
                "enddate",
                "courseimage", 
                "progress" 
            ]
        }
    }
]



(Note: Additional helpful fields like courseimage and progress can be appended to requiredfields if supported by the server).

5.2 Fetching Notifications / Calendar Events

Endpoint: POST https://lms.cuchd.in/lib/ajax/service.php?sesskey=<sesskey>&info=core_calendar_get_action_events_by_timesort

Headers: Includes Moodle Session cookies.

Payload:

[
    {
        "index": 0,
        "methodname": "core_calendar_get_action_events_by_timesort",
        "args": {
            "limitnum": 10,
            "timesortfrom": 1790620200,
            "timesortto": 1791225000,
            "limittononsuspendedevents": true
        }
    }
]



(Note: The app will need a helper function to dynamically generate timesortfrom and timesortto as UNIX timestamps based on the current date).

6. Data Modeling Strategy (Pre-development)

Since the exact JSON response structures for the Moodle AJAX calls are currently unknown, the development process will follow this strict sequence before creating Dart models:

Test Authentication: Run a test script using a valid student credential to pass the SSO flow and capture a valid MoodleSession cookie and sesskey.

cURL Response Mapping:
Construct curl requests in the terminal using the captured cookie and sesskey to hit both the courses and notifications endpoints.
Example:
curl -X POST "https://lms.cuchd.in/lib/ajax/service.php?sesskey=YOUR_SESSKEY&info=..." -H "Cookie: MoodleSession=YOUR_COOKIE" -d '[...PAYLOAD...]'

Model Generation: Analyze the raw JSON output from curl. Use this payload to generate robust Dart data classes (e.g., using freezed and json_serializable) to safely parse the LMS responses in the app.




### Content Analysis & Dynamic Extraction Logic

Based on the provided HTML files, the LMS delivers course content primarily in two structural formats.

**1. Single Document Viewer (Resource View)**
This layout is used for individual files like presentations or PDFs.

* **Title:** Located inside `<div class="page-header-headings"><h1 class="h2 mb-0">`.


* **Viewer URL:** Embedded within an `<iframe>` with the ID `resourceobject`. The `src` attribute contains the `pdf.php` URL you identified.


* **Download URL:** Attached to an anchor tag with the classes `btn btn-primary` and a `download` attribute.



**2. Folder/Directory Explorer (Folder View)**
This layout is used for a collection of grouped files.

* **Title:** Also located inside `<div class="page-header-headings"><h1 class="h2 mb-0">`.


* **File List:** Contained within a nested `<ul>` structure under `<div id="folder_tree0" class="filemanager">`.


* **Individual Files:** Defined by `<span class="fp-filename">` wrapping an `<a>` tag containing the direct download URL (`pluginfile.php`) and the file name.


* **File Types:** Indicated by the `src` of the `<img>` tag within the adjacent `<span class="fp-icon">` (e.g., `.../f/document` for Word, `.../f/powerpoint` for PPT).



### Dynamic Extraction Script

To make the extraction dynamic across multiple pages on this LMS, you can use the following JavaScript in the browser console or within a scraping tool (like Puppeteer/Cheerio) to automatically detect the page type and build a standardized JSON object.

```javascript
function extractLMSContent() {
    const contentData = {
        pageTitle: document.querySelector('.page-header-headings h1')?.innerText || "Unknown Title",
        type: null,
        items: []
    };

    // Check for Single Document Viewer (PPT/PDF)
    const viewerIframe = document.querySelector('iframe#resourceobject');
    if (viewerIframe) {
        contentData.type = 'single_document';
        contentData.items.push({
            name: document.querySelector('.local-officeviewer-filename')?.innerText || contentData.pageTitle,
            viewerUrl: viewerIframe.src,
            downloadUrl: document.querySelector('a.btn-primary[download]')?.href
        });
        return contentData;
    }

    // Check for Folder View
    const folderTree = document.querySelector('#folder_tree0');
    if (folderTree) {
        contentData.type = 'folder_directory';
        const fileNodes = folderTree.querySelectorAll('.fp-filename a');
        
        fileNodes.forEach(node => {
            // Traverse up to find the associated icon
            const iconNode = node.closest('.fp-filename-icon')?.querySelector('.fp-icon img');
            let fileType = 'unknown';
            if (iconNode && iconNode.src.includes('/f/document')) fileType = 'docx';
            if (iconNode && iconNode.src.includes('/f/powerpoint')) fileType = 'pptx';
            if (iconNode && iconNode.src.includes('/f/pdf')) fileType = 'pdf';

            contentData.items.push({
                name: node.innerText,
                downloadUrl: node.href,
                type: fileType
            });
        });
        return contentData;
    }

    return contentData;
}

```

### Extracted Data from Provided Sources

Running the logic above on your provided files yields:

From PPT Type:

* **Page Title:** Lecture 8,9 PPTX


* **Viewer URL:** `[https://lms.cuchd.in/local/officeviewer/pdf.php?id=3435104&h=bd9cf54c3c34e05c9683542a029b650bebae5826](https://lms.cuchd.in/local/officeviewer/pdf.php?id=3435104&h=bd9cf54c3c34e05c9683542a029b650bebae5826)`

* **Download URL:** `[https://lms.cuchd.in/pluginfile.php/4726581/mod_resource/content/1/Lecture%208%2C9.pptx?forcedownload=1](https://lms.cuchd.in/pluginfile.php/4726581/mod_resource/content/1/Lecture%208%2C9.pptx?forcedownload=1)`


From Folder Type:

* **Page Title:** Course Contents


* **Files:**
* *Lecture_40_42_Concurrency_Control.docx* (Word Document)


* *Lecture_43_44_45_Database_Recovery.docx* (Word Document)


* *Database-Unit-3-Chapter8- Lecture 40, 41, 42.pptx* (PowerPoint)


* *Database-Unit3-Chapter9- Lecture 43, 44.pptx* (PowerPoint)


* *Database-Unit3-Chapter9- Lecture 45.pptx* (PowerPoint)





---

### Dynamic UI Screen Implementation

Here is a clean, modern HTML/CSS/JS frontend that consumes the dynamically extracted JSON format and renders the appropriate UI depending on whether the content is a single document or a folder.

Save this code as an `.html` file and open it in a browser to view the unified interface.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Dynamic Course Content Viewer</title>
<style>
    :root {
        --primary: #e82427;
        --bg-color: #f8fafc;
        --card-bg: #ffffff;
        --text-main: #1d2125;
        --text-muted: #64748b;
        --border: #e2e8f0;
    }
    body {
        font-family: 'Segoe UI', system-ui, sans-serif;
        background-color: var(--bg-color);
        color: var(--text-main);
        margin: 0;
        padding: 2rem;
    }
    .container {
        max-width: 900px;
        margin: 0 auto;
    }
    .header {
        margin-bottom: 2rem;
        padding-bottom: 1rem;
        border-bottom: 2px solid var(--border);
    }
    .header h1 { margin: 0; font-size: 1.5rem; }
    
    /* Document Viewer Styles */
    .viewer-card {
        background: var(--card-bg);
        border: 1px solid var(--border);
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        margin-bottom: 2rem;
    }
    .viewer-toolbar {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1rem 1.5rem;
        background: #f1f5f9;
        border-bottom: 1px solid var(--border);
    }
    .viewer-toolbar span { font-weight: 600; }
    .btn {
        background: var(--primary);
        color: white;
        padding: 0.5rem 1rem;
        text-decoration: none;
        border-radius: 4px;
        font-size: 0.875rem;
        font-weight: 500;
        transition: opacity 0.2s;
    }
    .btn:hover { opacity: 0.9; }
    .iframe-container {
        position: relative;
        padding-bottom: 56.25%; /* 16:9 Aspect Ratio */
        height: 0;
    }
    .iframe-container iframe {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        border: 0;
    }

    /* Folder Explorer Styles */
    .folder-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
        gap: 1rem;
    }
    .file-card {
        background: var(--card-bg);
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 1rem;
        display: flex;
        align-items: flex-start;
        gap: 1rem;
        text-decoration: none;
        color: var(--text-main);
        transition: transform 0.2s, box-shadow 0.2s;
    }
    .file-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        border-color: var(--primary);
    }
    .file-icon {
        font-size: 1.5rem;
        flex-shrink: 0;
    }
    .file-details {
        overflow: hidden;
    }
    .file-name {
        font-size: 0.9rem;
        font-weight: 500;
        margin: 0 0 0.25rem 0;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }
    .file-type {
        font-size: 0.75rem;
        color: var(--text-muted);
        text-transform: uppercase;
    }
</style>
</head>
<body>

<div class="container" id="app">
    <!-- UI will be injected here dynamically -->
</div>

<script>
    // Simulated JSON data generated by the extraction script
    const extractedData = [
        {
            pageTitle: "Lecture 8,9 PPTX",
            type: "single_document",
            items: [{
                name: "Lecture 8,9.pptx",
                viewerUrl: "https://lms.cuchd.in/local/officeviewer/pdf.php?id=3435104&h=bd9cf54c3c34e05c9683542a029b650bebae5826",
                downloadUrl: "#"
            }]
        },
        {
            pageTitle: "Course Contents",
            type: "folder_directory",
            items: [
                { name: "Lecture_40_42_Concurrency_Control.docx", downloadUrl: "#", type: "docx" },
                { name: "Database-Unit-3-Chapter8- Lecture 40, 41, 42.pptx", downloadUrl: "#", type: "pptx" }
            ]
        }
    ];

    function getIconForType(type) {
        switch(type) {
            case 'pptx': return '📊';
            case 'docx': return '📄';
            case 'pdf': return '📕';
            default: return '📁';
        }
    }

    function renderUI(dataArray) {
        const app = document.getElementById('app');
        let html = '';

        dataArray.forEach(data => {
            html += `<div class="header"><h1>${data.pageTitle}</h1></div>`;

            if (data.type === 'single_document') {
                const item = data.items[0];
                html += `
                    <div class="viewer-card">
                        <div class="viewer-toolbar">
                            <span>📄 ${item.name}</span>
                            <a href="${item.downloadUrl}" class="btn">Download Original</a>
                        </div>
                        <div class="iframe-container">
                            <!-- Placeholder for iframe to prevent live loading in this demo -->
                            <div style="display:flex; align-items:center; justify-content:center; height:100%; background:#e2e8f0;">
                                <p style="color:#64748b">Iframe Viewer: ${item.viewerUrl}</p>
                            </div>
                        </div>
                    </div>
                `;
            } else if (data.type === 'folder_directory') {
                html += `<div class="folder-grid">`;
                data.items.forEach(item => {
                    html += `
                        <a href="${item.downloadUrl}" class="file-card">
                            <div class="file-icon">${getIconForType(item.type)}</div>
                            <div class="file-details">
                                <h3 class="file-name" title="${item.name}">${item.name}</h3>
                                <span class="file-type">${item.type} File</span>
                            </div>
                        </a>
                    `;
                });
                html += `</div>`;
            }
        });

        app.innerHTML = html;
    }

    // Initialize the UI
    renderUI(extractedData);
</script>

</body>
</html>

```