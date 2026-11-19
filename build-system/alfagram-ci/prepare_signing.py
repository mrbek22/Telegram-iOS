#!/usr/bin/env python3
"""AlfaGram CI: App Store imzolash uchun codesigning papkasini tayyorlaydi.

App Store Connect API (env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8) orqali har bir bundle ID uchun
IOS_APP_STORE profilini oladi (bo'lmasa yaratadi) va tarqatish sertifikatini (env: IOS_DIST_P12_B64)
Make.py kutgan ko'rinishda joylaydi:

    <out>/certs/dist.p12          — parolsiz p12 (ImportCertificates.py `-P ''` bilan import qiladi)
    <out>/profiles/*.mobileprovision

Ishlatish:  python3 prepare_signing.py <out_dir> <bundle_id>
Hech qanday maxfiy qiymat logga chiqarilmaydi.
"""
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

import jwt  # pip install pyjwt cryptography

API = "https://api.appstoreconnect.apple.com/v1"
SUFFIXES = ["", ".Share", ".NotificationService", ".NotificationContent", ".SiriIntents", ".Widget", ".BroadcastUpload"]


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:800]}")


def main():
    out, bundle = sys.argv[1], sys.argv[2]
    os.makedirs(out + "/certs", exist_ok=True)
    os.makedirs(out + "/profiles", exist_ok=True)

    with open(out + "/certs/dist.p12", "wb") as f:
        f.write(base64.b64decode(os.environ["IOS_DIST_P12_B64"]))

    certs = call("GET", "/certificates?filter[certificateType]=DISTRIBUTION&limit=50")["data"]
    if not certs:
        raise SystemExit("Distribution sertifikati topilmadi")
    cert_ids = [c["id"] for c in certs]

    for suffix in SUFFIXES:
        ident = bundle + suffix
        found = call("GET", f"/bundleIds?filter[identifier]={ident}&limit=5")["data"]
        found = [b for b in found if b["attributes"]["identifier"] == ident]
        if not found:
            raise SystemExit(f"Bundle ID ro'yxatdan o'tmagan: {ident}")
        bid = found[0]["id"]
        name = "AlfaGram AppStore" + (suffix or "")
        profs = call("GET", f"/bundleIds/{bid}/profiles?limit=50")["data"]
        profs = [p for p in profs if p["attributes"]["profileType"] == "IOS_APP_STORE"
                 and p["attributes"]["profileState"] == "ACTIVE"]
        if profs:
            content = profs[0]["attributes"]["profileContent"]
            print(f"profil bor: {ident}")
        else:
            r = call("POST", "/profiles", {"data": {"type": "profiles",
                     "attributes": {"name": f"{name} {int(time.time())}", "profileType": "IOS_APP_STORE"},
                     "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}},
                                       "certificates": {"data": [{"type": "certificates", "id": c} for c in cert_ids]}}}})
            content = r["data"]["attributes"]["profileContent"]
            print(f"profil yaratildi: {ident}")
        fname = (suffix.lstrip(".") or "Telegram") + ".mobileprovision"
        with open(out + "/profiles/" + fname, "wb") as f:
            f.write(base64.b64decode(content))


if __name__ == "__main__":
    main()
