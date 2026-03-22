# Juicd

iOS app prototype — ranked sports picks, weekly tournaments, groups, and profile badges.

- **Setup (Xcode, Supabase, odds, App Store):** see [`JUICD_SETUP.md`](JUICD_SETUP.md)

## Before first commit

1. **Do not commit API keys.** Use Xcode target **Info** for `ODDS_API_KEY` locally, or copy `Local.xcconfig.example` → `Local.xcconfig`, add your key there, and add that file to **.gitignore** (already ignored).
2. From the **repo root** (the folder that contains `Juicd.xcodeproj` and this `README.md`):

   ```bash
   git add .
   git commit -m "Initial commit"
   ```

   (If you haven’t run `git init` yet, do that once first.)

3. Create an empty repo on GitHub, then:

   ```bash
   git branch -M main
   git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
   git push -u origin main
   ```
