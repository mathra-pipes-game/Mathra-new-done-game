# OWNER APP • ඔයාගේ පාලක ඇප් එක
The control panel is a SEPARATE app (`Mathra_Pipes_Admin.zip`), not part of the game – players never see it.
Build it, install it only on your phone, log in with your admin e-mail. See its README.md.
(The `web/` folder is an optional website version of the same panel – you do not need it.)

# Shop + Web Admin setup  •  වෙළඳසැල + වෙබ් Admin සකසන හැටි

## How it works • වැඩ කරන විදිය
1. Player: game -> **Shop** -> picks a plan -> **Order** (an order with a code like `K7M2QX9A` is created, WhatsApp opens).
2. Player pays you (bank / eZ Cash etc. – details are shown from the admin panel).
3. You open **admin.html** -> **Orders** -> check the money really arrived -> **Approve**.
4. Approve writes `licenses/<DeviceID>` (plan + expiry). The game reads it (every 10 s while the Shop is open) and unlimited hints start.
5. The plan **ends by itself** (expiry is checked with Google's SERVER time, so changing the phone date does nothing). You can also press **Remove** in Subscriptions to cut it any time.

There is NO unlock code inside the app any more. The old secret/`make_code.py` was removed because a secret inside an APK can be extracted. Premium exists only if YOU approved it on the web.

## One-time setup (about 10 minutes) • එක පාරක් කරන්න ඕන දේවල්
1. Firebase console -> your project `mathra-pipes-game`.
2. **Build -> Authentication -> Sign-in method -> Email/Password -> Enable.**
   **Users -> Add user** -> your admin e-mail + a strong password.
3. Open `firestore.rules`, replace `CHANGE_ME_ADMIN_EMAIL@example.com` with that e-mail.
   Firestore -> **Rules** -> paste the whole file -> **Publish**.
4. Put the website online (free): install Firebase CLI, then in this folder:
   `firebase login` -> `firebase init hosting` (public dir = `web`) -> `firebase deploy --only hosting`.
   Your site: `https://mathra-pipes-game.web.app` (public prices) and `/admin.html` (your panel).
   If your address is different, change `HintConfig.webUrl` in `lib/data/services/hint_config.dart`.
5. Open `/admin.html`, log in -> **Prices** -> **Load default plans** -> **Save prices**.
   Also fill payment info + WhatsApp number -> **Save**.
6. Rebuild the app. Prices you edit later appear in the game and on the website automatically.

## Default prices • දැනට දාලා තියෙන මිල
1 day Rs 5 • 2 days Rs 10 • 1 month Rs 100 • 2 months Rs 200 • 6 months Rs 500 • 1 year Rs 1000
(edit / hide / add any plan in admin -> Prices)

## Hint rules • ඉඟි නීති
* 3 free hints once per phone, at the start.
* Every 400 leaderboard points = +3 hints (never repeated for the same points).
* The player who TAKES the online #1 spot gets +3 once. The player who drops to #2 gets nothing. When #2 becomes #1 he gets +3.
  (`meta/top` in Firestore remembers the current #1.)
* Active subscription = unlimited hints.

## Dashboard numbers • Dashboard එකේ පේන දේවල්
Installs (one record per phone) • App opens • Website visits • Orders (bought) • Pending • Paid (approved by you) • Revenue • Active premium • Players.
"Paid" and "Revenue" use the REAL plan price from your Prices list, not the price the phone sent.

## Honest limits • දැනගන්න ඕන සීමා
* Leaderboard scores are still sent by the app itself, so a modified app could send fake scores (and win the #1 / 400-point hints). Use **Players -> Delete** to remove cheaters. Full protection needs a server (Cloud Functions, Blaze plan).
* Money is checked by YOU (bank/WhatsApp). The app cannot see payments by itself; to automate this later you need a payment gateway (PayHere etc.) + Cloud Functions.
* Installs = phones that opened the app (Firestore), not Play Store downloads.
