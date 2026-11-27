---
name: store-rejection
description: Handle a rejection or policy notice from Apple App Review or Google Play. Reads the message, finds the cause in the project with file:line evidence, decides whether to fix and resubmit, reply with a clarification, update a console form, or appeal, and drafts the Resolution Center reply or the Play appeal. Nothing is sent and no console is changed — the user does that. Works across Flutter, Expo, React Native, and Native Android/iOS projects.
---

# Store rejection

Goal: turn a rejection into a short, correct plan — the real cause, the smallest fix, which console forms to change, and, when there is a channel for it, a reply or appeal the user can paste. Talk to the user in their language and write the response file in it too; only the reply / appeal draft is in English (reviewers read English), followed by a translation when the user writes in another language.

**Read-only.** Do not change the project; describe fixes, apply them only when the user asks afterwards. Write `REJECTION_RESPONSE.md` (and any audit output) in `<project>/build/reports/store-rejection/` when git ignores that folder (`git check-ignore -q build/reports`), otherwise in a folder outside the project, or where the user asks.

This skill uses the guides and scripts of the **flutter-store-ready** skill installed next to it (`<kit>` = `<this skill's folder>/../flutter-store-ready`) and `REJECTIONS.md` in this folder.

## 1. Get the exact message

Ask for the full text if the user paraphrased it: the guideline or policy names and numbers, the reviewer's wording, attached screenshots, the version / build number, the device and OS they tested on, the date. Do not reason from a summary — a single word ("crash", "metadata", "demo account") changes the answer.

Write down, quoting the message:

- **Store and severity.** Apple: rejected build (Resolution Center) or metadata rejection (no new build needed). Google: rejected update, app removed / suspended, or a warning with a deadline (write the deadline down).
- **Cited rule(s)** — exactly as written.
- **What the reviewer saw** — steps, screen, device.

## 2. Find the cause in the project

1. Look the rule up in `REJECTIONS.md`: where to look and what usually causes it. Check that the row's assumption holds for this app (e.g. a subscription row when the app sells no subscription). If the rule is not listed, read its current text (links at the top of `REJECTIONS.md`).
2. Run the automated audit (supports Flutter, Expo, React Native, and Native Android/iOS):
   ```sh
   dart run <kit>/scripts/project_report.dart <project> --skip-gates --out <report folder>
   ```
   Exit code 1 only means blocking items were found. Read `PROJECT_REPORT.md` for the overview and `PLAY_READINESS.md` / `APP_STORE_READINESS.md` for the store details. The merged Android manifest exists only after a local release build and may be older than the code: for what Google reviewed, ask the user to check Play Console → App bundle explorer.
3. Reproduce what the reviewer describes in the code (manifest, `Info.plist` / `app.json`, the screen named). A crash on the reviewer's device needs the crash log from App Store Connect / Xcode Organizer or Play Console (Android vitals / pre-launch report).
4. **When the answer depends on something only the console shows** (product types, current form answers, listing text, review notes): ask the user before choosing a path, and document each branch in the file.
5. State the cause with `file:line` or the console setting. If you cannot find it, say so plainly and draft a specific question for the reviewer — never invent a fix.

## 3. Decide the path

| Situation | Path |
|---|---|
| The reviewer is right and the cause is in the code or build | **Fix → new build → resubmit**, with a reply that says what changed |
| Only store listing, screenshots, description or a console form is wrong | **Fix in the console → resubmit**, no new build (Apple metadata rejection; Play declarations) |
| The reviewer could not reach the feature (sign-in, region, hardware, hidden paywall) | **Reply with access details** — demo account, steps, video link — usually no new build |
| The reviewer misread the app and you can show it | **Reply with a clarification** (Apple) / **appeal** (Google), with evidence: steps, screenshots, video, exact rule text |
| The cause depends on console settings you cannot see | **Ask the user first** (step 2.4); prepare each branch |
| Google says the app is removed or the account is at risk | **Fix first, then appeal or resubmit**; check the deadline; do not upload unrelated changes in the same release |

Prefer fixing over appealing when both are viable without breaking the product. Never recommend hiding features or behaving differently during review.

## 4. Write REJECTION_RESPONSE.md

1. **Summary** — store, rule, one-sentence cause, chosen path.
2. **Evidence** — `file:line`, console setting, quote of the reviewer.
3. **Fix** — concrete steps (for Flutter apps, follow `<kit>/EXISTING-PROJECTS.md` and the `<kit>` guides).
4. **Console tasks** — every form to update (use **store-forms** when full answers are needed).
5. **Before resubmitting** — how to verify the fix (test, audit item now ✅, console screenshot, fresh install on device).
6. **Other risks found** — separate list (`file:line`) of un-cited issues likely to trigger the next rejection.
7. **Reply / appeal draft** (English, plus a translation if the user writes in another language), or `"No reply needed — update the form and resubmit"` for Play form-only fixes.

In chat, in the user's language: the cause, the path, the first thing to do (or question to answer), and where the file is.

## Never

- Send the reply or appeal, change any console setting, or upload a build.
- Write real passwords, keys or personal data into the response file.
- Claim it is fixed before the fix is verified.
- Suggest reviewer detection, feature hiding, or opening a duplicate developer account / app listing.
