#!/usr/bin/env python3
"""Pregatirea unui build pentru TestFlight, prin App Store Connect API:

1. inregistreaza bundle ID-ul in contul de dezvoltator, daca lipseste;
2. afla echipa (Team ID);
3. verifica daca exista aplicatia in App Store Connect (nu se poate crea prin API);
4. alege numarul de build: cel mai mare build urcat + 1.

Scrie TEAM_ID si BUILD_NUMBER in $GITHUB_ENV.
Variabile: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY, BUNDLE_ID, APP_NAME.
"""
import base64
import json
import os
import re
import sys
import textwrap
import time
import urllib.error
import urllib.request

import jwt  # PyJWT

BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ["BUNDLE_ID"]
APP_NAME = os.environ.get("APP_NAME", "Golul de Aur")


def private_key() -> str:
    raw = os.environ["ASC_PRIVATE_KEY"].strip().replace("\\n", "\n")
    if "BEGIN" not in raw:
        try:
            dec = base64.b64decode(raw).decode()
            if "BEGIN" in dec:
                raw = dec
        except Exception:
            pass
    body = re.sub(r"-----(BEGIN|END) [A-Z ]+-----", "", raw)
    body = re.sub(r"\s+", "", body)
    return "-----BEGIN PRIVATE KEY-----\n" + "\n".join(textwrap.wrap(body, 64)) + "\n-----END PRIVATE KEY-----\n"


def token() -> str:
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"].strip(), "exp": int(time.time()) + 15 * 60, "aud": "appstoreconnect-v1"},
        private_key(), algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"})


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> HTTP {e.code}\n{e.read().decode(errors='replace')}")


def main():
    found = api("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE_ID}&limit=20")["data"]
    bundle = next((b for b in found if b["attributes"]["identifier"] == BUNDLE_ID), None)
    if not bundle:
        # Numele unui bundle ID accepta doar litere, cifre si spatii.
        bundle_name = re.sub(r"\s+", " ", re.sub(r"[^A-Za-z0-9 ]", " ", APP_NAME)).strip()
        bundle = api("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE_ID, "name": bundle_name, "platform": "IOS"}}})["data"]
        print(f"Bundle ID inregistrat acum: {BUNDLE_ID}")
    team = bundle["attributes"]["seedId"]

    # Game Center: capabilitatea trebuie sa fie activa pe bundle ID, altfel profilul nu o contine.
    caps = api("GET", f"/v1/bundleIds/{bundle['id']}/bundleIdCapabilities")["data"]
    if not any(c["attributes"]["capabilityType"] == "GAME_CENTER" for c in caps):
        api("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
            "attributes": {"capabilityType": "GAME_CENTER"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}}}})
        print("Game Center activat pe bundle ID")

    apps = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        raise SystemExit(
            f"::error::Bundle ID-ul {BUNDLE_ID} e inregistrat, dar aplicatia nu exista inca in App Store Connect. "
            f"Creeaz-o: appstoreconnect.apple.com -> Apps -> + -> New App (iOS, nume '{APP_NAME}', "
            f"bundle ID {BUNDLE_ID}), apoi ruleaza din nou.")
    builds = api("GET", f"/v1/builds?filter[app]={apps[0]['id']}&sort=-uploadedDate&limit=50")["data"]
    numbers = [int(b["attributes"]["version"]) for b in builds if b["attributes"]["version"].isdigit()]
    build = max(numbers, default=0) + 1
    print(f"Echipa {team}, build nou {build}")

    out = os.environ.get("GITHUB_ENV")
    if out:
        with open(out, "a") as f:
            f.write(f"TEAM_ID={team}\nBUILD_NUMBER={build}\n")


if __name__ == "__main__":
    sys.exit(main())
