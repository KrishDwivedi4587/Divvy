# Running Divvy on an iPhone

Divvy runs on an iPhone through **Expo Go**, loading from your Windows laptop over
the network. No Mac, no Xcode and no Apple Developer account is needed.

> **Status:** everything here has been prepared and checked from the laptop side.
> The project was upgraded to SDK 58 after the iPhone's Expo Go rejected SDK 57.
> It has **not yet been confirmed to open on the iPhone**. The steps marked ✅ below are things
> that were verified on the laptop; the rest is what you will confirm on the phone.

---

## One-time setup

### 1. Create a free Expo account

Go to <https://expo.dev/signup> and sign up. Expo Go now requires you to be logged
in, on **both** the laptop and the phone, **with the same account**
([Expo's announcement](https://expo.dev/changelog/expo-go-57-login)). It is free.

### 2. Install Expo Go on the iPhone

App Store → search **Expo Go** → install.

### 3. Make sure Expo Go and the project are on the same SDK

Divvy is on **Expo SDK 58**. The Expo Go app from the App Store reported SDK 58.0.0
when this was first tried, which is why the project was upgraded from SDK 57.
Expo Go only opens projects built for its own SDK, and an iPhone's Expo Go cannot
be downgraded, so the project has to follow it. If Expo Go is ever updated to a
newer SDK than 58, see
[If Expo Go and the project don't match](#if-expo-go-and-the-project-dont-match).

### 4. Sign in on the laptop

```bash
cd C:\Users\ASUS\Documents\College\divvy
npx expo login
```

Follow the link it prints and sign in with your browser. (You can check it worked
with `npx expo whoami`. It said "Not logged in" when this was prepared.)

### 5. Sign in on the phone

Open Expo Go → **Home** → tap the **avatar icon in the upper-right** → sign in
with the same Expo username and password.

---

## Start the app

### 6. Start the development server

```bash
cd C:\Users\ASUS\Documents\College\divvy
npm install        # only if you haven't run it, or after pulling changes
npx expo start --clear
```

A QR code appears in the terminal. `--clear` empties Metro's cache, which you want
after the SDK 58 upgrade; the first bundle then takes a minute.

✅ Verified on this laptop: the server starts, reports "Using src/app as the root
directory for Expo Router", and answers HTTP 200 on the laptop's LAN address.

### 7. Open it on the iPhone

Put the iPhone on the **same Wi-Fi network as the laptop**. Open the iPhone's
**Camera** app, point it at the QR code, and tap **Open in Expo Go**.

Alternatively, with both devices signed in to the same account, the server
appears under **Development servers** on Expo Go's Home tab. Tap it.

The first load bundles the app and takes a little longer.

---

## If it won't connect

Work down this list. Most failures are the network, not the app.

| Symptom                                  | Likely cause                                                                     | Fix                                                  |
| ---------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Stuck on "Opening project…" or times out | Wi-Fi isolates devices from each other. Campus and public networks often do this | Use **tunnel mode** (below) or the **hotspot** trick |
| Works on home Wi-Fi, not at college      | Same as above                                                                    | Same fix                                             |
| Windows pops up a firewall prompt        | First run                                                                        | Tick **Private networks** and allow                  |
| "Network response timed out"             | Laptop and phone on different networks, or a VPN is running                      | Same Wi-Fi, VPN off                                  |

### Tunnel mode ✅

```bash
npm run start:tunnel
```

Routes the connection through Expo's servers, so it works across network
isolation. Slower to start and a little slower to reload. ✅ Verified: tunnel mode
starts and prints a tunnel URL from this laptop (SDK 58) (`@expo/ngrok` is installed as a
dev dependency so it doesn't stop to prompt).

### The hotspot trick

Turn on the iPhone's **Personal Hotspot** and connect the laptop to it. The two
are then on the same private network with no isolation, and `npx expo start` works
as normal. Most reliable at a venue you don't control.

### Windows firewall

Checked on this laptop: its network is classed **Public**, and Node.js already has
inbound **Allow** rules for the Public profile, so the firewall should not block
LAN mode here. A different machine or network may differ.

---

## If Expo Go and the project don't match

Expo Go supports one SDK at a time and the iPhone's copy cannot be downgraded.
Divvy is on **SDK 58**.

**"Project is incompatible with this version of Expo Go":** read the SDK number
Expo Go shows.

- **It says SDK 58 and the project is on 58:** you are probably still talking to an
  old Metro server or cached manifest. Stop every old server (Ctrl+C), close the
  project in Expo Go, run `npx expo start --clear` and scan the _new_ QR code.
- **Expo Go has moved to a newer SDK** (59 or later): upgrade the project one SDK
  at a time with `npx expo install expo@^<next> ` then `npx expo install --fix`,
  following [Expo's upgrade walkthrough](https://docs.expo.dev/workflow/upgrading-expo-sdk-walkthrough/),
  and re-run `npm run check`. This has not been done or tested beyond 58.

### Plan B: run it in iPhone Safari

The app also runs as a website, which needs no Expo Go and no account:

```bash
npx expo start --web
```

Then open `http://<laptop-ip>:8081` in **Safari on the iPhone** (same Wi-Fi). The
laptop's address is shown by `ipconfig` under your Wi-Fi adapter.

What to expect: the whole flow works and has been verified in a browser at phone
size, but **not in iPhone Safari**. "Take photo" sets the standard HTML `capture`
attribute on a file input, which mobile browsers use to offer the camera. That
attribute is confirmed to be set; that Safari then opens the camera has not been
confirmed. Differences from Expo Go: it is a web page, icons are Material rather
than SF Symbols, and "Open Settings" is not available. Treat it as a safety net,
and test it before relying on it.

---

## Demo script

The target demonstration, about two minutes:

1. **Open Divvy.** Home shows the brand, two actions, how-it-works and an empty
   "Recent bills".
2. Tap **New bill**.
3. Tap **Take photo**. Allow the camera when iOS asks. Photograph a real bill.
4. **Preview** shows the photo whole. Show **Retake photo**, then tap **Use this
   photo**.
5. **Bill details.** The photo is pinned at the top; tap it to view it full screen.
   Enter a name and the amount from the bill. Add a tax %, a tip, and a service
   charge. The **Total** at the bottom updates as you type.
6. Tap **Continue**. **Add people**: type names and tap **Add** (or Return).
7. Tap **See summary.** Each person's amount, tap one to expand the breakdown. The
   amounts add up to the total exactly.
8. Tap **Share summary** to show the iOS share sheet, then **Save & finish**. The
   bill appears under Recent bills.

Then show the second path: **Upload a bill photo** from Home, which opens your
photo library and joins the same Preview.

Good test figures: bill ₹1,000, service charge 10%, tax 5%, tip ₹50, three people
gives **₹401.69 / ₹401.66 / ₹401.65**, totalling **₹1,205.00**.

---

## Device checklist

Tick these off on the phone. Until they are ticked, the camera and gallery are
**implemented but not verified on an iPhone**.

- [ ] Expo Go opens the project (SDK compatible)
- [ ] **Take photo** opens the iPhone camera
- [ ] A photo taken reaches **Preview**, whole and the right way up
- [ ] **Retake photo** replaces it
- [ ] **Upload from gallery** opens the photo picker
- [ ] A chosen photo reaches Preview; **Choose another** replaces it
- [ ] Cancelling the camera or picker returns quietly, with the photo kept
- [ ] **Camera denied:** iPhone **Settings → Expo Go → Camera** off, then tap
      **Take photo**. You should see _"Camera access is off"_ with **Open
      Settings**, and the gallery should still work
- [ ] Decimal keypad: the amount fields have no Return key on iOS. Check that you
      can dismiss the keyboard (drag down, or tap outside) and that **Continue**
      stays reachable
- [ ] Nothing is hidden under the notch or home indicator
- [ ] **Share summary** opens the iOS share sheet with the text
- [ ] The photo's orientation is correct for photos taken in portrait and landscape

## Known limitations on the phone

- **No OCR.** The photo is shown beside manual entry. Nothing is read from it, and
  no extracted values are ever shown.
- **Equal split only.** Everyone pays an equal share; splitting by item is not in
  this version.
- **Recent bills reset when the app is closed.**
- **Expo Go shows "Expo Go" in permission prompts and in Settings**, not "Divvy".
  Divvy's own permission text applies to a built app, not Expo Go.
- The decimal keypad has no Return key on iOS (an iOS limitation). This is the
  most likely rough edge to meet on the phone.
