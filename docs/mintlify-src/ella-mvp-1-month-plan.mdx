# ELLA Voice Tutor — 1-Month MVP Team Resource & Implementation Plan

This document maps out the weekly deliverables, file targets, and resource distribution for the ELLA MVP (starting **May 27, 2026**). It is updated to **defer the offline-first caching layer** (focusing on direct online API integration), **remove the Garden UI rewards/streaks system**, and **explicitly schedule only working days** (excluding Saturdays and Sundays).

---

## 👥 ELLA Project Team Roles
*   **[Backend] User (You):** Handles FastAPI database migrations, direct progress APIs, SQLite WAL configuration, and background task processing.
*   **[Android] Dhansri:** Handles Flutter state management, local `due_next` selector logic, direct API client integration (online only), and UI screens.
*   **[Designer] Narendra:** Reviews and designs layouts, topics styling, Home screen visuals, and asset mappings.
*   **[Product] Piyush:** Manages milestones, coordinates user flows, handles telemetry logs analysis, and supervises pilot onboarding.
*   **[Pedagogy] Prachi:** Leads system prompt engineering (`conversation-prompt.md` and `evaluate-skills-prompt.md`), validates the A1/A2 level profiles, and conducts transcript scoring audits.

---

## 📅 Calendar Day-by-Day Scheduling (Excludes Weekends)

The project runs over **23 working days** total. Saturdays and Sundays are non-working rest days:

```
[Sprint 1: May 27 - Jun 2] ──> [Sprint 2: Jun 3 - Jun 9] ──> [Sprint 3: Jun 10 - Jun 16] ──> [Sprint 4: Jun 17 - Jun 23] ──> [Launch: Jun 24 - Jun 26]
```

### 🚀 Sprint 1: May 27 – June 2 (5 Working Days)
*   **Day 1 (Wed, May 27):** Sprint Kickoff & Spec Alignment
*   **Day 2 (Thu, May 28):** Backend model & Dart schema model design
*   **Day 3 (Fri, May 29):** **[Backend: User]** DB Migration & **[Android: Dhansri]** Skill Models completed.
*   *Weekend (Sat, May 30 & Sun, May 31):* Non-working days.
*   **Day 4 (Mon, Jun 1):** **[Backend: User]** Progress endpoints (`GET /progress/skills`) completed.
*   **Day 5 (Tue, Jun 2):** **[Android: Dhansri]** API client calls integrated.

#### Task Assignments:
1. **[Backend: User]** DB Schema Migration (ETA: May 29)
   * *Task:* Add `UserSkill` model and modify the `User` table to include `times_spoken_total`. Generate and apply local Alembic migration.
   * *Files:*
     * [NEW] [user_skill.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/models/user_skill.py)
     * [MODIFY] [user.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/models/user.py)
     * [NEW] `migrations/versions/002_add_user_skills.py`
2. **[Android: Dhansri]** UserSkill Dart Model (ETA: May 29)
   * *Task:* Create the Dart model for user skill progress (matching DB fields: skill_id, state, confidence, strength, last_seen).
   * *Files:*
     * [NEW] `frontend/lib/models/user_skill.dart`
3. **[Backend: User]** Progress REST Endpoints & WAL Mode (ETA: Jun 1)
   * *Task:* Develop progress APIs: `GET /progress/skills` and `POST /progress/sync` for online fetching/updating. Configure SQLite WAL mode in database setup to support concurrent writes.
   * *Files:*
     * [MODIFY] [progress.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/routers/progress.py)
     * [MODIFY] [database.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/core/database.py)
4. **[Android: Dhansri]** API Client Integration (ETA: Jun 2)
   * *Task:* Integrate direct API calls to fetch skills and update progress from the frontend client. Connect these with `ChatProvider` state.
   * *Files:*
     * [MODIFY] [api_service.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/services/api_service.dart)
     * [MODIFY] [chat_provider.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/providers/chat_provider.dart)

### 💬 Sprint 2: June 3 – June 9 (5 Working Days)
*   **Day 6 (Wed, Jun 3):** Prompt template variables setup.
*   **Day 7 (Thu, Jun 4):** **[Android: Dhansri & Design: Narendra]** Home topics layout updated.
*   **Day 8 (Fri, Jun 5):** **[Android: Dhansri]** `due_next` selector logic completed.
*   *Weekend (Sat, Jun 6 & Sun, Jun 7):* Non-working days.
*   **Day 9 (Mon, Jun 8):** **[Pedagogy: Prachi & Backend: User]** Prompt assembly proxy logic completed.
*   **Day 10 (Tue, Jun 9):** Sprint integration testing & review.

#### Task Assignments:
1. **[Designer: Narendra]** Home Topics Redesign & Styling (ETA: Jun 4)
   * *Task:* Review text styling and padding, mapping home page topics to the 11 A1 themes.
   * *Files:*
     * [MODIFY] [home_screen.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/screens/home_screen.dart)
2. **[Android: Dhansri]** Swap Home Screen to A1 Topics (ETA: Jun 4)
   * *Task:* Implement the redesigned home page topics list to match Narendra's specs.
   * *Files:*
     * [MODIFY] [home_screen.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/screens/home_screen.dart)
3. **[Android: Dhansri]** `due_next` Selector Queue (ETA: Jun 5)
   * *Task:* Implement the 3-bucket queue selector algorithm on the client side (using retrieved online memory/state).
   * *Files:*
     * [MODIFY] [chat_provider.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/providers/chat_provider.dart)
4. **[Pedagogy: Prachi]** A1/A2 Profile Prompt Tuning (ETA: Jun 8)
   * *Task:* Draft and validate level profile prompt instructions ensuring Zoe active scaffolding.
   * *Files:*
     * [MODIFY] [conversation-prompt.md](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/assets/prompts/conversation-prompt.md)
5. **[Backend: User]** Dynamic Prompt Assembly Proxy (ETA: Jun 8)
   * *Task:* Modify the backend LLM service to dynamically inject target skill details into the system prompt.
   * *Files:*
     * [MODIFY] [llm_service.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/services/llm_service.py)

### 🧠 Sprint 3: June 10 – June 16 (5 Working Days)
*   **Day 11 (Wed, Jun 10):** Evaluation prompt drafting.
*   **Day 12 (Thu, Jun 11):** **[Pedagogy: Prachi & Product: Piyush]** Rubric prompt completed.
*   **Day 13 (Fri, Jun 12):** **[Backend: User]** Async background task grading runner completed.
*   *Weekend (Sat, Jun 13 & Sun, Jun 14):* Non-working days.
*   **Day 14 (Mon, Jun 15):** **[Android: Dhansri]** Optimistic transitions completed.
*   **Day 15 (Tue, Jun 16):** **[Backend: User & Android: Dhansri]** Staging deployment complete.

#### Task Assignments:
1. **[Pedagogy: Prachi]** Forced-Commit Evaluation Rubric (ETA: Jun 11)
   * *Task:* Design the evaluation system prompt. Force a binary assessment of target skills, ignoring spelling/phonetic errors.
   * *Files:*
     * [NEW] `frontend/assets/prompts/evaluate-skills-prompt.md`
2. **[Product: Piyush]** Rubric Review & Latency Checks (ETA: Jun 11)
   * *Task:* Review evaluation criteria and coordinate test scenarios.
3. **[Backend: User]** Async Background Task Runner (ETA: Jun 12)
   * *Task:* Integrate FastAPI `BackgroundTasks` to trigger the Judge LLM evaluation out-of-band post-chat.
   * *Files:*
     * [MODIFY] [llm.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/routers/llm.py)
4. **[Android: Dhansri]** Optimistic State Transitions (ETA: Jun 15)
   * *Task:* Optimistically increment spoken count on session completion and update UI before fetching newly evaluated progress.
   * *Files:*
     * [MODIFY] [chat_provider.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/providers/chat_provider.dart)
5. **[Backend: User]** Staging Server Setup (ETA: Jun 16)
   * *Task:* Set up and deploy the updated FastAPI backend server to the staging environment.
6. **[Android: Dhansri]** Staging Build Integration (ETA: Jun 16)
   * *Task:* Connect the Flutter app to the staging API endpoints for end-to-end testing.

### 🧪 Sprint 4: June 17 – June 23 (5 Working Days)
*   **Day 16 (Wed, Jun 17):** Network drop test case scenarios preparation.
*   **Day 17 (Thu, Jun 18):** **[Android: Dhansri & Backend: User]** Direct API network latency & drop QA complete.
*   **Day 18 (Fri, Jun 19):** **[Android: Dhansri & Pedagogy: Prachi]** Pedagogy transcript grading audit complete.
*   *Weekend (Sat, Jun 20 & Sun, Jun 21):* Non-working days.
*   **Day 19 (Mon, Jun 22):** Bug fixing for edge cases.
*   **Day 20 (Tue, Jun 23):** **[Android: Dhansri & Backend: User]** Crash testing & error handlers complete.

#### Task Assignments:
1. **[Android: Dhansri]** Client Network Resilience (ETA: Jun 18)
   * *Task:* Add timeout and error boundaries to Flutter API calls for graceful recovery under unstable school network conditions.
   * *Files:*
     * [MODIFY] [api_service.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/services/api_service.dart)
2. **[Backend: User]** Network Latency Logging (ETA: Jun 18)
   * *Task:* Implement backend response-time tracking to isolate bottleneck sources.
   * *Files:*
     * [MODIFY] [llm_service.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/services/llm_service.py)
3. **[Pedagogy: Prachi]** Transcript Grading Audit (ETA: Jun 19)
   * *Task:* Conduct a grading quality audit of 20 mock conversations to verify accuracy of the Judge.
4. **[Android: Dhansri]** Edge Case Error UI (ETA: Jun 23)
   * *Task:* Add fallback interfaces and user alerts for failed connections, empty transcripts, and LLM timeouts.
   * *Files:*
     * [MODIFY] [conversation_screen.dart](file:///Users/sama/AndroidStudioProjects/ella_flutter/frontend/lib/screens/conversation_screen.dart)
5. **[Backend: User]** Robust API Handlers (ETA: Jun 23)
   * *Task:* Implement fallback error responses for OpenAI/Gemini rate-limits and database lockups.
   * *Files:*
     * [MODIFY] [progress.py](file:///Users/sama/AndroidStudioProjects/ella_flutter/backend/app/routers/progress.py)

### 📦 Production Deployment & Pilot Release (3 Working Days)
*   **Day 21 (Wed, Jun 24):** **[Backend: User]** Production Deploy & DB migrations executed.
*   **Day 22 (Thu, Jun 25):** **[Android: Dhansri]** Production Release APK packaged.
*   **Day 23 (Fri, Jun 26):** **[Product: Piyush & Pedagogy: Prachi]** Pilot Launch & live monitoring active.

#### Task Assignments:
1. **[Backend: User]** Live Production Deploy (ETA: Jun 24)
   * *Task:* Build and deploy production Docker containers. Execute migrations on live Postgres/SQLite.
2. **[Android: Dhansri]** Release APK Packaging (ETA: Jun 25)
   * *Task:* Build final production APK. Package using dynamic Whisper model pre-fetching (Option B) to target ~25MB base APK size.
3. **[Product: Piyush]** Pilot Onboarding & Telemetry (ETA: Jun 26)
   * *Task:* Onboard pilot students and set up monitoring dashboards for response latencies and system errors.
4. **[Pedagogy: Prachi]** Live Pilot Grading Monitoring (ETA: Jun 26)
   * *Task:* Review initial live transcript evaluations to ensure correct level progression.
