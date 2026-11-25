---
name: store-rejection
description: Handle a rejection or policy notice from Apple App Review or Google Play. Reads the message, finds the cause in the project with file:line evidence, decides whether to fix and resubmit, reply with a clarification, update a console form, or appeal, and drafts the Resolution Center reply or the Play appeal. Nothing is sent and no console is changed — the user does that. Use when the user pastes a rejection, a "Guideline x.y" message, a Play Console policy email or warning, "uygulamam reddedildi", "Google'dan politika maili geldi".
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

1. Look the rule up in `REJECTIONS.md`: where to look and what usually causes it. Rows are starting points — check that the row's assumption holds for this app (e.g. a subscription row when the app sells no subscription). If the rule is not listed, read its current text (links at the top of `REJECTIONS.md`).
2. Collect evidence. For a Flutter app run the audit; it finds many causes directly:
   ```sh
   dart run <kit>/scripts/project_report.dart <project> --skip-gates --out <report folder>
   ```
   Exit code 1 only means blocking items were found. Read `PROJECT_REPORT.md` for the overview and `PLAY_READINESS.md` / `APP_STORE_READINESS.md` for the store details. The merged Android manifest exists only after a local release build and may be older than the code (the report says when): for what Google reviewed, the user can check Play Console → App bundle explorer. For other project types read the files the rule points to (manifest, Info.plist / app.json, the screen the reviewer named).
3. Reproduce what the reviewer describes when you can (the flow in the code, the build they tested). A crash on the reviewer's device needs the crash log: ask the user for it from App Store Connect (TestFlight / Xcode Organizer) or Play Console (Android vitals, pre-launch report).
4. **When the answer depends on something only the console shows** (product types, the current form answers, the listing text, review notes): ask the user before choosing a path, and in the file give the branches ("if App Store Connect has no subscription product → …; if it has one → …").
5. State the cause with `file:line` or the console setting. If you cannot find it, say so plainly and draft a specific question for the reviewer — do not invent a fix.

## 3. Decide the path

| Situation | Path |
|---|---|
| The reviewer is right and the cause is in the code or build | **Fix → new build → resubmit**, with a reply that says what changed |
| Only store listing, screenshots, description or a console form is wrong | **Fix in the console → resubmit**, no new build (Apple metadata rejection; Play declarations) |
| The reviewer could not reach the feature (sign-in, region, hardware, hidden paywall) | **Reply with access details** — demo account, steps, video link — usually no new build |
| The reviewer misread the app and you can show it | **Reply with a clarification** (Apple) / **appeal** (Google), with evidence: steps, screenshots, video, the exact rule text |
| The cause depends on console settings you cannot see | **Ask the user first** (step 2.4); prepare each branch |
| Google says the app is removed or the account is at risk | **Fix first, then appeal or resubmit**; check the deadline; do not upload unrelated changes in the same release |

When fixing and appealing are both possible, prefer the fix unless it would break the product: appeals take longer and a rejected appeal costs more time. Never recommend hiding a feature from reviewers or behaving differently during review.

## 4. Write REJECTION_RESPONSE.md

1. **Summary** — store, rule, one-sentence cause, chosen path.
2. **Evidence** — what in the project causes it (`file:line`, console setting, quote of the reviewer).
3. **Fix** — concrete steps. For a Flutter app the fixes follow the **flutter-store-ready** guides.
4. **Console tasks** — every form to update (Data safety, App Privacy, App access / App Review Information, Advertising ID, content rating, target audience, export compliance …) and what to enter. **store-forms** drafts complete answers.
5. **Before resubmitting** — what proves it is fixed: the test, the audit item now ✅, the console screen showing the new answer, the screen on a real device, a fresh install.
6. **Other risks found** — problems you noticed that were not cited but are likely to cause the next rejection (one line each, with `file:line`). Do not mix them into the reply.
7. **Reply / appeal draft** (English), only when there is a channel for it — Apple: always a Resolution Center reply; Google: an appeal when you disagree, or the policy form's message field. For a Play form fix with no message channel, write "No reply needed — update the form and resubmit" instead. A draft:
   - thanks the reviewer once and restates the issue in one line;
   - says what changed, or why the app complies — specific, with steps to see it ("Settings → Account → Delete account");
   - points to access details ("credentials are in App Review Information"), never the password itself;
   - lists attachments to add (screenshots, a short screen recording);
   - makes no promise that is not true, blames no one, does not argue about other apps.

In chat, in the user's language: the cause, the path, the first thing to do (or the question you need answered), and where the file is.

## Never

- Send the reply or the appeal, change any console setting, or upload a build — the user does it.
- Write real passwords, keys or personal data into the response file.
- Claim it is fixed before the fix is verified.
- Suggest detecting reviewers or hiding features during review, or a new developer account / the same app under another name to get around a decision.
