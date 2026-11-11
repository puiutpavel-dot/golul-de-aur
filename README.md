# Golden Goal (Golul de Aur)

Joc iOS (SwiftUI): un meci real pe zi, 15 trepte până la un milion de puncte virtuale. Tradus în 8 limbi (en, es, fr, de, pt-BR, it, ar, ro); aplicația urmează limba telefonului.

- `GolulDeAur/` + `project.yml`: aplicația (proiectul Xcode se generează cu XcodeGen).
- `scripts/sync.mjs`: alege zilnic meciul cu cele mai apropiate cote 1-X-2 și ia scorul final.
- `data/matches.json`: datele pe care le citește aplicația; actualizat automat.
- `.github/workflows/sync.yml`: rulează scriptul la fiecare 30 de minute.
- `.github/workflows/ios.yml`: verificare la fiecare push; manual, cu acțiunea `testflight`, urcă build-ul semnat în TestFlight.

## Configurare

1. Repo-ul trebuie să fie public (aplicația citește `data/matches.json` direct din el).
2. Settings → Secrets and variables → Actions → New repository secret:
   nume `ODDS_API_KEY`, valoare = cheia de la the-odds-api.com.
3. Dacă repo-ul are alt nume decât `puiutpavel-dot/golul-de-aur`, schimbă adresa din
   `GolulDeAur/Backend.swift`.

## TestFlight

1. Secrete în repo: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (aceleași ca la celelalte aplicații).
2. Actions → iOS → Run workflow → `testflight`. Prima rulare înregistrează bundle ID-ul
   `ro.draghicioiu.goluldeaur` și se oprește dacă aplicația nu există încă în App Store Connect.
3. Creezi aplicația în App Store Connect (Apps → + → New App) și rulezi din nou.
