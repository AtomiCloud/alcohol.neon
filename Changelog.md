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
