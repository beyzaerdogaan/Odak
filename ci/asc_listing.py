#!/usr/bin/env python3
"""Writes the App Store listing from appstore/listing.json through the App Store Connect API.

  asc_listing.py <listing.json> [<screenshots dir>]

For each locale in the JSON: name, subtitle and privacy policy URL on the app info; description, keywords,
promotional text, support and marketing URLs on the version being prepared. With a screenshots dir, also
replaces that version's 6.9" iPhone screenshots with <dir>/<locale>/*.png in name order.
Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (see asc_signing.py).
"""
import hashlib
import json
import os
import sys
import urllib.request

from asc_signing import call

BUNDLE_ID = "com.beyzaerdogan.derin"
# App Store Connect files 6.9" iPhone screenshots (1320x2868) under the 6.7" display type.
DISPLAY_TYPE = "APP_IPHONE_67"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW"}


def upsert(kind, existing, locale, attrs, parent_rel, parent_id):
    found = next((x for x in existing if x["attributes"]["locale"] == locale), None)
    if found:
        call("PATCH", f"/{kind}/{found['id']}", {"data": {"type": kind, "id": found["id"], "attributes": attrs}})
        print(f"updated {kind} {locale}")
        return found["id"]
    created = call("POST", f"/{kind}", {"data": {"type": kind, "attributes": {"locale": locale, **attrs},
        "relationships": {parent_rel: {"data": {"type": parent_rel + "s", "id": parent_id}}}}})
    print(f"created {kind} {locale}")
    return created["data"]["id"]


def upload_screenshots(localization_id, folder):
    sets = call("GET", f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]
    shot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE), None)
    if shot_set:
        for old in call("GET", f"/appScreenshotSets/{shot_set['id']}/appScreenshots")["data"]:
            call("DELETE", f"/appScreenshots/{old['id']}")
        set_id = shot_set["id"]
    else:
        set_id = call("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY_TYPE}, "relationships": {"appStoreVersionLocalization":
            {"data": {"type": "appStoreVersionLocalizations", "id": localization_id}}}}})["data"]["id"]
    for name in sorted(f for f in os.listdir(folder) if f.endswith(".png")):
        data = open(os.path.join(folder, name), "rb").read()
        shot = call("POST", "/appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            part = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=part, method=op["method"],
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            urllib.request.urlopen(req).read()
        call("PATCH", f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(f"uploaded {os.path.basename(folder)}/{name}")


def main():
    listing = json.load(open(sys.argv[1]))
    shots = sys.argv[2] if len(sys.argv) > 2 else None

    app = call("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})["data"][0]["id"]
    infos = call("GET", f"/apps/{app}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") in EDITABLE
                 or i["attributes"].get("state") in {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED"}), infos[0])
    versions = call("GET", f"/apps/{app}/appStoreVersions", query={"filter[platform]": "IOS"})["data"]
    version = next(v for v in versions if v["attributes"]["appStoreState"] in EDITABLE)
    print(f"version {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")

    info_locs = call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]
    version_locs = call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    for locale, text in listing.items():
        upsert("appInfoLocalizations", info_locs, locale,
               {k: text[k] for k in ("name", "subtitle", "privacyPolicyUrl")}, "appInfo", info["id"])
        loc_id = upsert("appStoreVersionLocalizations", version_locs, locale,
                        {k: text[k] for k in ("description", "keywords", "promotionalText", "supportUrl", "marketingUrl")},
                        "appStoreVersion", version["id"])
        if shots and os.path.isdir(os.path.join(shots, locale)):
            upload_screenshots(loc_id, os.path.join(shots, locale))


if __name__ == "__main__":
    main()
