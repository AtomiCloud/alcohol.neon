## [1.13.2](https://github.com/AtomiCloud/alcohol.neon/compare/v1.13.1...v1.13.2) (2026-07-30)


### 🐛 Bug Fixes 🐛

* classify http 400/401 refresh rejections as dead sessions too ([6725460](https://github.com/AtomiCloud/alcohol.neon/commit/6725460067b1bd990aab82acbfe52c9ca175f3c7))
* dead session at token refresh lands on sign-in, not frozen loader ([ef30ce2](https://github.com/AtomiCloud/alcohol.neon/commit/ef30ce283634942b1c05db1227e192f802c59846))

## [1.13.1](https://github.com/AtomiCloud/alcohol.neon/compare/v1.13.0...v1.13.1) (2026-07-29)


### 🐛 Bug Fixes 🐛

* publish signed-out before cleanup and only wipe dead sessions ([2682b02](https://github.com/AtomiCloud/alcohol.neon/commit/2682b02ce05678d132b68152c0f541f09d13eadb))
* recover from a dead stored session instead of hanging on splash ([4e1a17d](https://github.com/AtomiCloud/alcohol.neon/commit/4e1a17db761786eac11fd02d58c8ae840edf8739))

## [1.13.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.6...v1.13.0) (2026-07-28)


### ✨ Features ✨

* single nfc tag domain t.lazytax.club served by alcohol.helium ([eb10c5e](https://github.com/AtomiCloud/alcohol.neon/commit/eb10c5e6f72eda180448e9ffd2075c312379b25b))

## [1.12.6](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.5...v1.12.6) (2026-07-19)


### 🐛 Bug Fixes 🐛

* re-read ndef in-session before classifying a tag as blank ([19d31b4](https://github.com/AtomiCloud/alcohol.neon/commit/19d31b4a6de42fcce29a448cd5c0eed042ffae53))

## [1.12.5](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.4...v1.12.5) (2026-07-19)


### 🐛 Bug Fixes 🐛

* poll only iso14443/iso15693 so ios does not demand felica config ([b867fad](https://github.com/AtomiCloud/alcohol.neon/commit/b867fad71f4226dede9b2d67d60448af3d727e6c))

## [1.12.4](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.3...v1.12.4) (2026-07-12)


### 🚀 Performance Improvement 🚀

* **ci:** build the iOS donor with constant version fields too ([7fdea0c](https://github.com/AtomiCloud/alcohol.neon/commit/7fdea0c66534f4c16a5abe29da551b8c8ba631ea)), closes [#39](https://github.com/AtomiCloud/alcohol.neon/issues/39)

## [1.12.3](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.2...v1.12.3) (2026-07-12)


### 🚀 Performance Improvement 🚀

* **ci:** build the Android donor with constant version fields ([68d5466](https://github.com/AtomiCloud/alcohol.neon/commit/68d546679e6576ee6a6d129c1a56ca8f94e89be1))

## [1.12.2](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.1...v1.12.2) (2026-07-12)


### 🚀 Performance Improvement 🚀

* **ci:** retain release artifacts for 14 days instead of 90 ([5d98421](https://github.com/AtomiCloud/alcohol.neon/commit/5d984217586f41167857b33c4f2cc775f54f32a3))

## [1.12.1](https://github.com/AtomiCloud/alcohol.neon/compare/v1.12.0...v1.12.1) (2026-07-12)


### 🚀 Performance Improvement 🚀

* **ci:** enable the Gradle build cache for the donor build ([d9d945d](https://github.com/AtomiCloud/alcohol.neon/commit/d9d945d56f4ca006261596a8078d33dedba0e88a))
* **ci:** persist the Gradle cache in the Android donor build ([a4abcc8](https://github.com/AtomiCloud/alcohol.neon/commit/a4abcc82c444a05f5c1db12373a2cb2c22736c85))

## [1.12.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.11.0...v1.12.0) (2026-07-11)


### 📜 Documentation 📜

* note the team Apple ID in register-apple.sh header ([94e9e88](https://github.com/AtomiCloud/alcohol.neon/commit/94e9e8844ffb57c58a468f9af3489b2285333387))
* **register:** pin down the pls register contract ([8a58cba](https://github.com/AtomiCloud/alcohol.neon/commit/8a58cbafeced1bb1a6c73650a7079341ad5e64b0))
* redact personal apple id email from register script comment ([131f1c5](https://github.com/AtomiCloud/alcohol.neon/commit/131f1c5fe8cfa8dd156b2be684c84b982578db8d))
* refer to lpsm.yaml for the apple team instead of inlining the id ([c83a3f3](https://github.com/AtomiCloud/alcohol.neon/commit/c83a3f376f791126b4d23fed976472a70f2f7530))


### ✨ Features ✨

* **register:** declare Apple capabilities in lpsm.yaml (portal IaC) ([aa1c27d](https://github.com/AtomiCloud/alcohol.neon/commit/aa1c27d2d4e53913b4a1b13af1832f60839840ac))
* NFC habit tags - link, tap-to-complete, inspector ([e7048c0](https://github.com/AtomiCloud/alcohol.neon/commit/e7048c00234cd6145ba55d6979e972085078d722))
* register enables NFC + Associated Domains on the app id ([ca9af3b](https://github.com/AtomiCloud/alcohol.neon/commit/ca9af3b4830d35e5637a962c5afb8132f8df5a44))


### 🐛 Bug Fixes 🐛

* CodeRabbit nits - tag-id toast, base-url slash, mounted guard ([939f287](https://github.com/AtomiCloud/alcohol.neon/commit/939f2873dbd598c48442d4766e55335ddbfb02c5))
* **ios:** drop legacy NDEF value from the NFC formats entitlement ([4f20a9b](https://github.com/AtomiCloud/alcohol.neon/commit/4f20a9b5273c0e4b30aa44fea5a2a201e8bb9408))
* NFC review findings - cold-start links + NDEF dispatch ([3df9b70](https://github.com/AtomiCloud/alcohol.neon/commit/3df9b701ebdccb1fc7baf560f3620649c6a30145)), closes [llfbandit/app_links#209](https://github.com/llfbandit/app_links/issues/209) [#253](https://github.com/AtomiCloud/alcohol.neon/issues/253)
* **ci:** stamp with donor-derived entitlements for NFC capabilities ([f2cffbb](https://github.com/AtomiCloud/alcohol.neon/commit/f2cffbb25d32a33831f328f886ae5772bac98ffb))

## [1.11.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.10.0...v1.11.0) (2026-07-11)


### 🐛 Bug Fixes 🐛

* **ci:** address review — no secrets for build-android, guard re-export ([843d004](https://github.com/AtomiCloud/alcohol.neon/commit/843d004f5ab2fe06d71e1cea56a6a610ca8d9cbc))

## [1.10.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.9.0...v1.10.0) (2026-07-11)


### ✨ Features ✨

* **ci:** CI builds the donors; CD pulls, stamps, publishes ([0fd3d23](https://github.com/AtomiCloud/alcohol.neon/commit/0fd3d23833d432d7c84656ff7ea156a5c209ac4d))

## [1.9.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.8.0...v1.9.0) (2026-07-10)


### 🐛 Bug Fixes 🐛

* flip auth state before Logto revocation so sign-out never stalls ([af1c6a3](https://github.com/AtomiCloud/alcohol.neon/commit/af1c6a3078cb563c3fb7473d2b9135ec006ebadb))
* gate token providers on local auth state and surface empty-detail delete errors ([cbf8634](https://github.com/AtomiCloud/alcohol.neon/commit/cbf8634d64c69f51cf7f7b81e52f6423fdbe52db)), closes [#32](https://github.com/AtomiCloud/alcohol.neon/issues/32)
* pop navigator to root when auth session ends ([f018c40](https://github.com/AtomiCloud/alcohol.neon/commit/f018c40a4ab53f240c49d0996bd5fd8c8c84956b))
* surface tier-limit errors that arrived with an empty detail ([d74f38f](https://github.com/AtomiCloud/alcohol.neon/commit/d74f38f9b862f8b0af753f19ca5007e227a08745))
* treat cancelled login as benign instead of a failure ([194306b](https://github.com/AtomiCloud/alcohol.neon/commit/194306b43a7d48573751264ac21e7a1fca499677))


### 🧪 Tests 🧪

* inject an inert Logto client instead of stubbing secure storage ([49d02ab](https://github.com/AtomiCloud/alcohol.neon/commit/49d02ab8557b60237b12ac37ff54439ddb3c6327)), closes [#32](https://github.com/AtomiCloud/alcohol.neon/issues/32)

## [1.8.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.7.2...v1.8.0) (2026-07-08)


### ✨ Features ✨

* **ci:** build Android once and stamp per landscape ([e6a57ef](https://github.com/AtomiCloud/alcohol.neon/commit/e6a57ef34c3eafa271176dab28f1ccad39ae5aeb))
* **ci:** stamp iOS from one build; codemagic-cli-tools via nix ([4a1c9bc](https://github.com/AtomiCloud/alcohol.neon/commit/4a1c9bc9f8dfbfd093e3cd5b75af9c157c1746f5))


### 🐛 Bug Fixes 🐛

* **ci:** attempt every landscape's publish even after one fails ([a66dea4](https://github.com/AtomiCloud/alcohol.neon/commit/a66dea4a33b0825552c709bacfff36a8915d2b75))
* **ci:** keep embedded.mobileprovision in the stamped IPA ([00360a6](https://github.com/AtomiCloud/alcohol.neon/commit/00360a6ef9711f15bc505f743eb066fe3a32155a))

## [1.7.2](https://github.com/AtomiCloud/alcohol.neon/compare/v1.7.1...v1.7.2) (2026-07-07)


### 🐛 Bug Fixes 🐛

* **ios:** stop the widget target compiling Runner's bridging header ([53e1bfa](https://github.com/AtomiCloud/alcohol.neon/commit/53e1bfa2baff7dd7de0ae4aed7ecef8393e3e675))

## [1.7.1](https://github.com/AtomiCloud/alcohol.neon/compare/v1.7.0...v1.7.1) (2026-07-07)


### 🐛 Bug Fixes 🐛

* **ci:** doctor reads entitlements with PlistBuddy, not plutil keypaths ([f1762a5](https://github.com/AtomiCloud/alcohol.neon/commit/f1762a5b6a1b88e6a61209e7ea3378d1f81fe3a8))

## [1.7.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.6.1...v1.7.0) (2026-07-07)


### 📜 Documentation 📜

* cover Apple credentials in the store-credentials runbook ([63b734d](https://github.com/AtomiCloud/alcohol.neon/commit/63b734d1d3e871f93075457a42c183b690323965))


### ✨ Features ✨

* **register:** rotate provisioning profiles after association ([27b8f31](https://github.com/AtomiCloud/alcohol.neon/commit/27b8f314e30df449033f98399a0a1ce7c61f26ef))


### 🐛 Bug Fixes 🐛

* **register:** address review nits on rotation parsing and cert-cap doc ([ad05e64](https://github.com/AtomiCloud/alcohol.neon/commit/ad05e643f27de55e3f760c2170fa78dca5a5770f))
* **ci:** floor Android versionCode with the CI run number ([de9ad50](https://github.com/AtomiCloud/alcohol.neon/commit/de9ad50e0f7fc1e89de269f28e6d860bf1bb17c9))
* **register:** rotate profiles via ConnectAPI ([24f1530](https://github.com/AtomiCloud/alcohol.neon/commit/24f1530a6aa95bbe0c63dc279cf8fcd60b2b2ac7))
* the Apple team is MNPSXJP9PN, not the stale SY4WNY5G7U ([0cd72e5](https://github.com/AtomiCloud/alcohol.neon/commit/0cd72e56c589bc04e93c11bad5810b5d271a085e))

## [1.6.1](https://github.com/AtomiCloud/alcohol.neon/compare/v1.6.0...v1.6.1) (2026-07-07)


### 📜 Documentation 📜

* Play service-account setup runbook ([28c9b4a](https://github.com/AtomiCloud/alcohol.neon/commit/28c9b4ab91c83054199900e1cec62d6a37f56a4f))


### 🐛 Bug Fixes 🐛

* **ci:** doctor scans the Xcode 16 provisioning-profile directory ([f832510](https://github.com/AtomiCloud/alcohol.neon/commit/f83251089b8cd31e3a9749b225bd2aa65b92127c))

## [1.6.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.5.0...v1.6.0) (2026-07-07)


### ✨ Features ✨

* **register:** create ASC app records and auto-fill apple_ids ([b98c422](https://github.com/AtomiCloud/alcohol.neon/commit/b98c4221c5b3f33c83c80410ea295f3991f8e83a))
* lpsm.yaml as the single source of truth for store identifiers ([7febe7d](https://github.com/AtomiCloud/alcohol.neon/commit/7febe7d4e0e1ef7ad61c1bf7e74c9de1690db9e7))
* **register:** make the App Store name configurable via NEON_APP_NAME ([748271d](https://github.com/AtomiCloud/alcohol.neon/commit/748271d08cafd526fd24c283a5ab98e4d8df66cc))
* make the LPSM module segment mandatory (.app, .app.widget) ([16f9adb](https://github.com/AtomiCloud/alcohol.neon/commit/16f9adb7dcb31d701d2409d90678d667252b7fa0))
* name prod 'LazyTax: Stake Habits'; document store_suffix scope ([756595f](https://github.com/AtomiCloud/alcohol.neon/commit/756595f5ddea5534787776772b3217a3496f2813))


### 🐛 Bug Fixes 🐛

* **ci:** empty node_modules instead of removing the cache mountpoint ([60c081d](https://github.com/AtomiCloud/alcohol.neon/commit/60c081dd890e0010b0c5c0f23fdf8f7fda876266))
* **register:** explain identifier-reserved failures on create ([dab3539](https://github.com/AtomiCloud/alcohol.neon/commit/dab3539d69f9936763ae3a09049b6bc44dd54e92))
* **register:** look up apple_ids via ConnectAPI, surface failures ([a04e928](https://github.com/AtomiCloud/alcohol.neon/commit/a04e92816a305a452e4be1bfc9fde2364a6a79a9))
* **register:** parse fastlane output past its timestamp prefixes ([dcd227c](https://github.com/AtomiCloud/alcohol.neon/commit/dcd227cdc2f4bb3c97c34894e8dc78f2dc46721c))
* **register:** refuse to register under a foreign portal team ([c242206](https://github.com/AtomiCloud/alcohol.neon/commit/c24220647b1720a02cc28c9d776803a6974fbe44))
* **ci:** start semantic-release from a clean npm workdir ([bc50fa2](https://github.com/AtomiCloud/alcohol.neon/commit/bc50fa264cb423be7c64f47ef6d63b5360859e10))
* **register:** warn instead of hanging on unknown ASC teams ([934b7f3](https://github.com/AtomiCloud/alcohol.neon/commit/934b7f315445257ceb8ec04a0eed15756d459ccd))
* **register:** warn when a bundle id has no ASC app record ([5863ce8](https://github.com/AtomiCloud/alcohol.neon/commit/5863ce88a306a6b17f0194d72449f7d5df22947f))

## [1.5.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.4.0...v1.5.0) (2026-07-06)


### ✨ Features ✨

* **register:** enumerate Apple teams and prompt for the team up front ([8976ec8](https://github.com/AtomiCloud/alcohol.neon/commit/8976ec8ae424d57d65877b9687d8d5038132db5c))
* migrate store identifiers to the LPSM scheme ([49c4713](https://github.com/AtomiCloud/alcohol.neon/commit/49c4713124105028f889756dc73252b94fbf23af))


### 🐛 Bug Fixes 🐛

* **register:** sign in once up front, then run all landscapes hands-free ([564e8d6](https://github.com/AtomiCloud/alcohol.neon/commit/564e8d6bdc15f3a88242204afa113bc5ee6a6cc2))
* surface discovery and fastlane failures instead of swallowing them ([7f577b2](https://github.com/AtomiCloud/alcohol.neon/commit/7f577b22019b576b236536e9f3f1f30c81430f56))

## [1.4.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.3.0...v1.4.0) (2026-07-06)


### ✨ Features ✨

* **ios:** interactive home-screen widget with direct habit completion ([9acee8b](https://github.com/AtomiCloud/alcohol.neon/commit/9acee8bc078b0a3ed9f8e004e94c1da4e0e13129))
* subscription screen with web-handoff portal link ([da0f888](https://github.com/AtomiCloud/alcohol.neon/commit/da0f8886fc07a4b239e83478caefae53c5c72197))


### 🐛 Bug Fixes 🐛

* harden subscription handoff per code review ([f73da25](https://github.com/AtomiCloud/alcohol.neon/commit/f73da25f45f49764d732b7a3b0152497e92116e5))
* refresh subscription CTA when the app resumes ([140af1e](https://github.com/AtomiCloud/alcohol.neon/commit/140af1e2111ee73c585f5a5b2851752b71be2953))

## [1.3.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.2.0...v1.3.0) (2026-06-22)


### ✨ Features ✨

* add delete-account entry to profile ([df1680e](https://github.com/AtomiCloud/alcohol.neon/commit/df1680ed0a52f61ffb0c3a87b0b1b5ee74e47412))

## [1.2.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.1.0...v1.2.0) (2026-06-12)


### ✨ Features ✨

* extract mobile CD into reusable platform workflows ([36403a6](https://github.com/AtomiCloud/alcohol.neon/commit/36403a6dbf854b5430b6baeab54a3b03daa45061))

## [1.1.0](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.5...v1.1.0) (2026-06-09)


### ✨ Features ✨

* trigger release ([0b694a5](https://github.com/AtomiCloud/alcohol.neon/commit/0b694a53f54d88e731f15a8b7a4dfd895027ccd1))

## [1.0.5](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.4...v1.0.5) (2026-06-07)


### 🐛 Bug Fixes 🐛

* trigger release ([588b5ff](https://github.com/AtomiCloud/alcohol.neon/commit/588b5ffbea33b71060026b0f4e82d3330017dfb3))

## [1.0.4](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.3...v1.0.4) (2026-06-07)


### 🐛 Bug Fixes 🐛

* **ci:** drop ios_signing block so explicit profile creation runs ([a625a55](https://github.com/AtomiCloud/alcohol.neon/commit/a625a551ecf15e328bb80c52f863d8646866708e))

## [1.0.3](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.2...v1.0.3) (2026-06-07)


### 🐛 Bug Fixes 🐛

* **ci:** build Android on mac_mini_m2 ([9c9c41d](https://github.com/AtomiCloud/alcohol.neon/commit/9c9c41d9c8d05adb9d3db783b0dd83859daa1606))

## [1.0.2](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.1...v1.0.2) (2026-06-07)


### 🐛 Bug Fixes 🐛

* **ci:** create iOS signing profiles + correct Android keystore name ([3d0cd32](https://github.com/AtomiCloud/alcohol.neon/commit/3d0cd32ddac5425211fc1981955867e363552bc3))

## [1.0.1](https://github.com/AtomiCloud/alcohol.neon/compare/v1.0.0...v1.0.1) (2026-06-07)


### 🐛 Bug Fixes 🐛

* force a patch release ([ac98713](https://github.com/AtomiCloud/alcohol.neon/commit/ac98713c5cdc9f6198eaf863dee56115b0c5208b))

## 1.0.0 (2026-06-07)


### 📜 Documentation 📜

* park home-screen widget code (needs paid Apple acct / App Group) ([cc9dcfc](https://github.com/AtomiCloud/alcohol.neon/commit/cc9dcfcfde0b75c72143ac8956c8c454292cb176))
* update Codemagic + release runbooks ([062e9d7](https://github.com/AtomiCloud/alcohol.neon/commit/062e9d7c907ef02dd29ac2e7c4377b84591937b2))


### ✨ Features ✨

* add pichu/pikachu/raichu release channels (flavors + iOS CI) ([260d9d9](https://github.com/AtomiCloud/alcohol.neon/commit/260d9d9218599cab05279aab7a2ad3437ea89b2e))
* add put/patch/delete to ApiClient (shared _send) ([fc9c3c4](https://github.com/AtomiCloud/alcohol.neon/commit/fc9c3c4ae0c3283153cb46eda64f09dbf0d2a6d3))
* **M6:** Airwallex native-SDK payment consent for staking ([0e2d7ef](https://github.com/AtomiCloud/alcohol.neon/commit/0e2d7ef19a49f9d38a9602bfb2ba037e5339a950))
* **polish:** argon-grounded theme + semantic colors ([61c9c17](https://github.com/AtomiCloud/alcohol.neon/commit/61c9c1791dea77295452088ec840b92a3b943e82))
* **M1:** bootstrap + onboarding (timezone + default charity) ([40f3a38](https://github.com/AtomiCloud/alcohol.neon/commit/40f3a3893e9173c4c4a7d4097d78a09bd5c4fde8))
* **M4:** charity browse/search + detail (workflow + live fixes) ([7494c7c](https://github.com/AtomiCloud/alcohol.neon/commit/7494c7c5ecc24e9c7afef86eb918e7f32e78b189))
* **M2:** daily-loop dashboard (overview, complete/skip) ([e0b5d5e](https://github.com/AtomiCloud/alcohol.neon/commit/e0b5d5edd97a3d799be553e32ebd54e3296d61ed))
* dev config menu, Lottie loader, and UI fixes ([7bfdf4a](https://github.com/AtomiCloud/alcohol.neon/commit/7bfdf4a75dbe76886f46c09c512fcb1f5fced75a))
* domain repositories for all zinc domains (habit/execution/payment/protection/vacation/cause) ([4c0877c](https://github.com/AtomiCloud/alcohol.neon/commit/4c0877cf0f9f64442dc92002fde0993b3227c038))
* Flutter foundation + auth + branding ([037e07a](https://github.com/AtomiCloud/alcohol.neon/commit/037e07a73543d3cf45d120c45e13dc9a2b97a78e))
* **M3:** habit create/edit/delete + argon-style dashboard card ([08f8ea5](https://github.com/AtomiCloud/alcohol.neon/commit/08f8ea50290eb87b6bf39d03e97bbba4543ceedc))
* **polish:** local habit reminders (flutter_local_notifications) ([fad9c9f](https://github.com/AtomiCloud/alcohol.neon/commit/fad9c9ff7f57bb2a0492777ed8a38151d9e888a2))
* per-flavor identity (iOS schemes/bundle-ids + per-flavor icons) ([37f7752](https://github.com/AtomiCloud/alcohol.neon/commit/37f7752387cb7eee6cea36162905131262ec6e6f))
* **M7:** protections freeze balance + vacation windows ([6aa9141](https://github.com/AtomiCloud/alcohol.neon/commit/6aa91413d72e674d3e0b420faba9d66c1e32fee1))
* set pichu Logto native app id (sign-in verified) ([e29f1d4](https://github.com/AtomiCloud/alcohol.neon/commit/e29f1d421452768ea4454f9ffd204f90e1a34b9f))
* **M5:** settings + profile (workflow, reviews clean) ([11d2318](https://github.com/AtomiCloud/alcohol.neon/commit/11d23187e6f05409ed4f92a3656952b7447d1a97))
* **polish:** StakeSheet keypad stake entry ([21aa02e](https://github.com/AtomiCloud/alcohol.neon/commit/21aa02eed6bfe141a47e0239828d741ecd52aa9d))
* zinc repositories on generated DTOs (user/config/charity) ([cacca97](https://github.com/AtomiCloud/alcohol.neon/commit/cacca9767864630a0b73e1d38ccc20e65a34e038))


### 🐛 Bug Fixes 🐛

* **M1:** refresh id_token before POST /User; add sign-out on bootstrap error ([c7f95a7](https://github.com/AtomiCloud/alcohol.neon/commit/c7f95a70d5e01400db63ef631ce78c6fa1770fde))
* set iOS app display name to LazyTax (match Android + in-app) ([8e91fa9](https://github.com/AtomiCloud/alcohol.neon/commit/8e91fa9a8faf8a4791c3f59085f8388b5e7f0996))
