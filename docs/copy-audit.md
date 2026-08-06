# zoSpeak v0.0.5 copy audit

## Scope

Primary source: `/Users/kal/Downloads/zoSpeak.apk`

- Package: `org.navgurukul.ella`
- Version: `0.0.5` (build 5)
- Review method: clean Android emulator walkthrough plus a static string pass over the exact APK.
- Audience assumption: mostly children, while remaining welcoming and credible for teens and adults.
- Recommended voice: warm, simple, encouraging, and concrete—not babyish.

The APK is the source of truth. Workspace code was used only to understand where hard-to-reach strings appear.

## Overall verdict

The garden metaphor and Zoe’s encouraging tone are strong. The copy becomes weaker when it shifts between playful mascot language, formal product language, and raw engineering language.

The most important changes are:

1. Remove every raw exception, API label, hostname, route, and backend error from learner-facing screens.
2. Replace the absolute privacy promise on sign-in with accurate, linked privacy language.
3. Explain why age and placement questions are asked.
4. Separate child, teen, and adult topic suitability from English level.
5. Standardise sentence case, punctuation, and action labels.
6. Put destructive account actions behind an adult/guardian safeguard for child accounts.

## Recommended voice rules

- Use sentence case: `Continue with Google`, not `Continue With Google`.
- Keep buttons to one clear verb phrase: `Try again`, `Save changes`, `See all topics`.
- Prefer present tense: `Let’s talk about…`, not `I wanted to talk about…`.
- Use concrete language: `How old are you?`, not `I wanted to know what is your age?`.
- Give errors two parts: what happened and what to do.
- Let Zoe speak during learning moments. Use neutral product language for privacy, account, and technical states.
- Use British English consistently: `practise` as a verb, `favourite`, `colours`, `organise`.
- Avoid unnecessary exclamation marks. Save them for genuine celebrations.
- Use one ellipsis style everywhere: `…`.
- Keep the brand casing consistent. The APK currently mixes `zoSpeak` and `ZoSpeak`.

## Priority 0: release-blocking copy and trust issues

### Raw placement error

Current live result:

> Placement turn failed: ClientException with SocketException… ella.navgurukul.org… /api/llm/placement-turn

Recommended:

**Title:** `Zoe couldn’t connect`

**Body:** `Check your internet connection and try again.`

**Actions:** `Try again` · `Back`

Never show exception classes, server addresses, ports, API routes, stack traces, or the label `API Error`.

### Privacy promise

Current:

> Your learning data stays private and is never shared with anyone

This conflicts with the app’s own policy language, which says information may be shared to provide services and meet legal obligations.

Recommended:

> Your learning data is protected. Learn how we use it.

Make `Learn how we use it` a link to the privacy policy. Legal/privacy owners should approve the final sentence, especially because the product records speech and serves children.

### Child account safeguards

`Delete account` and `Clear learning progress` are available in the learner profile. For child accounts, these actions should require an adult/guardian step. Copy alone is not a sufficient safeguard.

### Topic suitability

The APK includes topics such as mental health, caste, stigma, privilege, migration, gender equality, and moral dilemmas. These can be valuable, but English level is not the same as age or emotional readiness.

Use separate topic suitability controls:

- Child-safe
- Teen
- Adult

For younger learners, use gentler framing and exclude sensitive topics by default. Confirm the server filters topics by age as well as CEFR level.

## Recommended copy deck

### Sign-in and email

| Current | Recommended |
|---|---|
| `ZoSpeak` | `zoSpeak` (or choose another casing and use it everywhere) |
| `Talk More. Grow Your English` | `Speak more. Grow your English.` |
| `Continue With Google` | `Continue with Google` |
| `Continue With Email` | `Continue with email` |
| `Your learning data stays private and is never shared with anyone` | `Your learning data is protected. Learn how we use it.` |
| `Sign In With Email` | `Sign in with email` |
| `We will send you a link. No password needed` | `We’ll email you a sign-in link—no password needed.` |
| `Eg. xyz@gmail.com` | `name@example.com` |
| `Send Me a Link` | `Send sign-in link` |
| `We have sent a link to {email}` | `We sent a sign-in link to {email}.` |
| `Open Your Inbox!` | `Open email app` |
| `Use a Different Email` | `Use another email` |
| `No mail app installed.` | `No email app found. Open your email in a browser.` |
| `Something went wrong. Please try again later.` | `Something went wrong. Try again.` |

### First-time onboarding

| Current | Recommended |
|---|---|
| `Hi, I'm Zoe. I'll help your English grow and want to know you better. What is your name?` | `Hi, I’m Zoe. I’ll help you practise speaking English. What should I call you?` |
| `Great, {name}. Next, I wanted to know what is your age?` | `Nice to meet you, {name}! How old are you? This helps me choose practice that fits you.` |
| Exact age text field | Prefer age bands: `Under 13`, `13–17`, `18+` |
| `Hmm, I don't think that was your name. Can you tell me your name again?` | `That doesn’t look like a name. Try the name you’d like Zoe to use.` |
| `I couldn't get your correct age. Can you please share your age again?` | `Enter your age as a number, like 10.` |
| `Alright {name}. Your garden is ready! Let's plant something` | `Great, {name}! Your garden is ready. Let’s grow your first plant.` |
| `Oops! I need the internet to do that.` | `You’re offline. Connect to the internet, then try again.` |
| `OK` | `Close` |

The name field should accept Unicode names. The current APK contains copy suggesting names must use letters only, and the matching validation appears limited to Latin characters.

### First garden and placement

| Current | Recommended |
|---|---|
| `Look, your first plant` | `Here’s your first plant` |
| `Every conversation grows something new here` | `Every conversation helps your garden grow.` |
| `Explore Garden` | `Explore your garden` |
| `I'd love to know more about you! Tell me about your world. It'll help your garden grow.` | `Let’s find a good place to start. I’ll ask a few questions about things you know and like. There are no wrong answers.` |
| `Let's Talk` | `Start talking` |
| `It was really nice talking with you, {name}! Let's talk again soon.` | `Thanks for talking with me, {name}. You can continue anytime.` |
| Raw placement exception | `Zoe couldn’t connect. Check your internet and try again.` |

The placement screen should say what is happening. The current garden language hides the fact that zoSpeak is choosing a starting level.

### Home and topic choice

| Current | Recommended |
|---|---|
| `This is our first chat together — I can't wait!` | `Ready for your first chat?` |
| `Next Session` | `Up next` |
| `Let's Talk` | `Start talking` |
| `Let's Talk About {topic}` | `Talk about {topic}` |
| `Not this topic. Pick your own.` | `Want a different topic?` |
| `See More!` | `See all topics` |
| `Choose any topic that you like` | `Choose a topic you’d like to talk about.` |
| `No topics to show yet.` | True empty state: `New topics will appear here soon.` |
| Network-caused empty list | `Topics couldn’t load.` plus `Try again` |
| `Today, I wanted to talk about {topic}. Shall we?` | `Today, let’s talk about {topic}. Ready?` |
| `Yesterday, we talked about {topic}.` | Keep |
| `Let's talk about something fun today. Shall we?` | `Let’s choose something fun to talk about.` |

### Conversation

| Current | Recommended |
|---|---|
| `Getting things ready...` | `Getting ready…` |
| `Tap to Speak` | `Tap to speak` |
| `Listening…` | Keep |
| `Zoe is talking…` | `Zoe is speaking…` |
| `Switch to Speaking` | `Switch to speaking` |
| Keyboard icon without visible label | Accessibility label: `Switch to typing` |
| End-call icon without visible label | Accessibility label: `Finish conversation` |
| `Need to go?` | `Finish for now?` |
| No supporting sentence | Add: `Your progress will be saved.` |
| `Keep talking` | Keep |
| `Bye for now, Zoe` | `Finish conversation` |
| `It was great talking to you. See you again later!` | `Great talking with you. See you next time!` |
| `Hey {name}, I'm having trouble connecting to the internet right now!` | `I’m having trouble connecting right now. Check your internet and try again.` |

### Garden and learning progress

| Current | Recommended |
|---|---|
| `Your flower is blooming!` | `Your plant is blooming!` |
| `You've got a brand new garden waiting with space for even more plants` | `Your new garden is ready—with room for more plants.` |
| `Your plant is soaking up sunshine. Let's talk again and watch it grow!` | `Your plant is soaking up sunshine. Talk again to help it grow.` |
| `Just a little more watering…` | `Zoe is checking what grew…` |
| `You watered your garden today` | `You practised today, and your garden got some water.` |
| `A line to remember` | `A sentence you used` |
| `What You Said` | `What you said` |
| `On Mastery, You Will Be Able To` | `When this blooms, you’ll be able to` |
| `Talk with Zoe to start growing this skill` | `Talk with Zoe to grow this skill.` |
| `A new skill is sprouting` | Keep |
| `This skill just grew stronger` | Keep |
| `This skill is in full bloom!` | Keep |
| `See Next Plant` | `See next plant` |
| `Explore Garden` | `Explore garden` |
| `Look at this! These are things you already know. Your garden was already grown` | `Look! Your earlier conversations have already grown this garden.` |
| `You're here` | Keep |
| `Keep growing {garden}. The next garden will open soon!` | `Keep practising to unlock the next garden.` |
| `Your garden is getting ready.` | Keep |
| `That was a quick hello 👋` | Keep |
| `We can talk more whenever you're ready` | `We can talk more whenever you’re ready.` |

The growth stages `Seed`, `Sprout`, `Budding`, and `Bloomed` are strong. Explain the four stages once, then keep the labels short.

### Profile and account

| Current | Recommended |
|---|---|
| `Edit Profile` | `Edit profile` |
| `{name}'s Profile` | `Edit profile` |
| `Update Profile` | `Save changes` |
| `Please enter a valid name and age.` | `Enter a name and age.` |
| `API Error` plus exception | `Couldn’t save changes. Try again.` |
| `Sound effects` / `Music and tap sounds` | `Sounds` / `Music and sound effects` |
| `Sign Out` | `Sign out` |
| `Clear Learning Progress?` | `Reset learning progress?` |
| Existing clear-progress body | `This deletes your level, garden, and conversation progress. Your account stays active. This can’t be undone.` |
| `Cancel` | `Keep progress` |
| `Clear Progress` | `Reset progress` |
| `Delete Account?` | `Delete zoSpeak account?` |
| Existing delete body | `This permanently deletes your profile, learning progress, conversations, and garden. This can’t be undone.` |
| `Cancel` | `Keep account` |
| `Delete Account` | `Delete account` |
| `Account deleted successfully.` | `Account deleted.` |

For child accounts, place clear/delete actions in an `Adult settings` area and require a guardian check.

### Offline and error states

| Current | Recommended |
|---|---|
| `No Internet Connection` | `You’re offline` |
| `Please check your internet connection and try again.` | `Connect to the internet, then try again.` |
| `Refresh` | `Try again` |
| `Oops! I need the internet to do that.` | `You’re offline. Connect to the internet, then try again.` |
| `OK` | `Close` |
| `Something went wrong. Please try again later.` | `Something went wrong. Try again.` |

Preserve learner input whenever an error appears and say so when helpful: `Your answer is still here.`

## Topic copy and safety

Keep light, concrete topics for younger learners:

- My family
- My school
- Food I like
- Animals
- Hobbies
- Sports
- Festivals
- My city
- Weather
- Films

Use clearer, age-aware framing for sensitive topics:

| Current | Younger/teen-friendly option |
|---|---|
| `Mental health and stigma` | `Feelings, support, and asking for help` |
| `Fake news and media literacy` | `How to spot false information` |
| `Gender equality in India` | `Fairness and equal opportunities` |
| `Privilege and opportunity` | `Why people get different opportunities` |
| `Caste, class, and social mobility` | Teen/adult only by default |
| `Moral dilemmas in everyday life` | `Making difficult choices` |
| `The ethics of artificial intelligence` | `How AI should be used` |

Avoid one-word card labels such as `Stigma`, `Privilege`, or `Caste` without context.

## Accessibility-related copy risks

- Several icon-only controls have no useful accessible name in the captured hierarchy, including some back, send, and call controls.
- `Speak again`, `Mute garden sound`, and `Unmute garden sound` are good semantic labels and should be the model for every icon button.
- The offline body text appears low contrast against the green background; verify contrast in code and with device testing.
- Do not rely on colour alone for microphone, growth, or destructive-action states.
- Keep error text visible until the learner dismisses it; a three-second toast may be too short for younger readers and screen-reader users.
- Screenshot review cannot verify keyboard navigation, TalkBack order, focus restoration, dynamic type, or full WCAG compliance.

## Captured flow

| Step | Screen | Health |
|---:|---|---|
| 1 | Sign-in landing | Needs revision |
| 2 | Email sign-in | Needs revision |
| 3 | Name onboarding | Mixed |
| 4 | Age onboarding | Poor wording |
| 5 | First-plant reveal | Good foundation |
| 6 | Placement introduction | Needs clearer purpose |
| 7 | Placement failure | Critical |
| 8 | Home | Mixed |
| 9 | Topic picker / empty state | Needs revision |
| 10 | Profile | Mixed |
| 11 | Edit profile | Needs revision |
| 12 | Delete account confirmation | Clear but needs adult safeguard |
| 13 | Offline state | Understandable, needs simpler actions |

## Evidence

1. `screenshots/01-first-launch.png`
2. `screenshots/02-email-sign-in.png`
3. `screenshots/03-onboarding-start.png`
4. `screenshots/04-onboarding-age.png`
5. `screenshots/05-onboarding-complete.png`
6. `screenshots/08-placement-intro.png`
7. `screenshots/09-placement-conversation.png`
8. `screenshots/10-home.png`
9. `screenshots/11-all-topics.png`
10. `screenshots/12-profile.png`
11. `screenshots/13-edit-profile.png`
12. `screenshots/14-delete-account.png`
13. `screenshots/15-garden.png`

## Evidence limits

- A real learner account was not used.
- The successful magic-link, successful placement result, live AI conversation, and post-session scoring response could not be completed end to end.
- Hard-to-reach fixed strings were verified through the exact APK’s compiled string table.
- AI-generated Zoe responses are dynamic and require a separate prompt/content-safety review.
- The audit does not claim legal compliance or full accessibility compliance.
