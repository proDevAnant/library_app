# Library Manager — Flutter App (Phase 6A)

## Is update mein kya hai
- Green / white / dark gray theme, Material 3
- Splash screen
- Login (mobile + password; zaroorat padne par library code bhi)
- Forgot password (email par 6-digit code) aur change password
- Role ke hisaab se app: Super Admin, Library Admin, Student
- **Library Admin dashboard:** students, aaj ki aur mahine ki fees, baaki fees, UPI verification alert, har shift ki seats, membership khatam hone wale students, mahine ki kamai / kharcha / net
- **Super Admin dashboard:** libraries, income, plan khatam hone wali libraries, support
- Notifications (bell icon, unread ginti ke saath), logout
- Internet na ho to "Try again" button; session khatam ho to apne aap login screen

Students, Fees, Libraries waghera ke tab abhi "next update" dikhayenge. Woh 6B aur 6C mein aayenge.

## Tarika 1: GitHub website se (CMD ki zaroorat nahi)
1. github.com par login karo → upar **+** → **New repository** → naam `library_app` → **Private** → **Create repository**.
2. Naye repo ke page par **"uploading an existing file"** link dabao.
3. Zip extract karo. `library_app` folder ke **andar ki saari cheezein** (`lib` folder, `pubspec.yaml`, `codemagic.yaml`, `.gitignore`, `README_HINDI.md`) browser mein drag karke chhod do.
   - `lib` folder ko poora drag karna hai, Chrome folder bhi upload kar deta hai.
4. Neeche **Commit changes** dabao.

## Tarika 2: Agar pehle se `library_app` project GitHub par hai (Part B wala)
1. Apne computer ke `library_app` folder mein purana `lib` folder delete karo.
2. Zip ka `lib`, `pubspec.yaml` aur `codemagic.yaml` wahan copy karo (Replace).
3. CMD mein:
```
cd %USERPROFILE%\Desktop\library_app
git add .
git commit -m "Phase 6A"
git push
```

## Codemagic se APK banana
1. codemagic.io → **Sign up / Log in with GitHub**.
2. **Add application** → GitHub → `library_app` chuno → type **Flutter App**.
3. Jab poochhe, **codemagic.yaml** wala option chuno.
4. **Start new build** → branch `main` → workflow **Android APK** → **Start**.
5. 10–15 minute baad build hara (green) ho jayega → **Artifacts** mein `app-release.apk` → download.
6. Phone par APK kholo. "Unknown apps install" ki permission maangega, de do.

`android` folder aur internet permission Codemagic apne aap bana deta hai, tumhe kuch nahi karna.

## Agar build laal (fail) ho jaye
Build par click karo → jo step laal hai use kholo → neeche ki **aakhri 30–40 lines** copy karke mujhe bhej do. Main turant theek kar dunga.

## Login karke check karo
- **Library Admin:** `9000000001` + Test Library ka password
- **Super Admin:** tumhara apna number + password
- **Student:** `9123456780` (Amit) + uska password
