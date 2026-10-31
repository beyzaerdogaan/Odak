#!/usr/bin/env python3
"""Prints what App Store Connect has for the version being prepared, to see what is left before review.

  asc_status.py

Read only. Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (see asc_signing.py).
"""
import json
import urllib.error
import urllib.parse
import urllib.request

from asc_signing import token

BUNDLE_ID = "com.beyzaerdogan.derin"
ROOT = "https://api.appstoreconnect.apple.com"
EU = {"AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL", "ITA",
      "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"}


def get(path, query=None, version="v1"):
    url = f"{ROOT}/{version}{path}" + ("?" + urllib.parse.urlencode(query) if query else "")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token()})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"  ! GET {path}: {e.code} {e.read().decode(errors='replace')[:300]}")
        return None


def section(title, value):
    print(f"\n== {title}")
    print(json.dumps(value, indent=2, ensure_ascii=False) if not isinstance(value, str) else value)


app = get("/apps", {"filter[bundleId]": BUNDLE_ID})["data"][0]
app_id = app["id"]
section("app", {k: app["attributes"].get(k) for k in ("name", "primaryLocale", "contentRightsDeclaration")})

versions = get(f"/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})["data"]
for v in versions:
    a = v["attributes"]
    section(f"version {a['versionString']}", {k: a.get(k) for k in ("appStoreState", "copyright", "releaseType", "earliestReleaseDate")})
version = versions[0]
vid = version["id"]

build = get(f"/appStoreVersions/{vid}/build")
section("attached build", build and build["data"] and {k: build["data"]["attributes"].get(k) for k in ("version", "processingState", "usesNonExemptEncryption")})

builds = get("/builds", {"filter[app]": app_id, "sort": "-uploadedDate", "limit": 3})
section("latest builds", [{k: b["attributes"].get(k) for k in ("version", "processingState", "uploadedDate", "usesNonExemptEncryption")} for b in builds["data"]])

review = get(f"/appStoreVersions/{vid}/appStoreReviewDetail")
if review and review.get("data"):
    a = review["data"]["attributes"]
    section("review detail", {k: (bool(a.get(k)) if k in ("contactPhone", "contactEmail", "demoAccountPassword") else a.get(k)) for k in a})
else:
    section("review detail", "none")

for loc in get(f"/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
    a = loc["attributes"]
    sets = get(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    shots = {s["attributes"]["screenshotDisplayType"]: len(get(f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]) for s in sets}
    section(f"localization {a['locale']}", {"description": bool(a.get("description")), "keywords": bool(a.get("keywords")),
        "supportUrl": a.get("supportUrl"), "screenshots": shots})

for info in get(f"/apps/{app_id}/appInfos")["data"]:
    iid = info["id"]
    a = info["attributes"]
    primary = get(f"/appInfos/{iid}/primaryCategory")
    secondary = get(f"/appInfos/{iid}/secondaryCategory")
    age = get(f"/appInfos/{iid}/ageRatingDeclaration")
    section(f"app info ({a.get('state') or a.get('appStoreState')})", {
        "appStoreAgeRating": a.get("appStoreAgeRating"),
        "primaryCategory": primary and primary["data"] and primary["data"]["id"],
        "secondaryCategory": secondary and secondary["data"] and secondary["data"]["id"],
        "ageRatingDeclaration": age and age["data"] and age["data"]["attributes"]})
    for loc in get(f"/appInfos/{iid}/appInfoLocalizations")["data"]:
        la = loc["attributes"]
        section(f"app info {la['locale']}", {k: la.get(k) for k in ("name", "subtitle", "privacyPolicyUrl")})

prices = get(f"/apps/{app_id}/appPriceSchedule/manualPrices", {"include": "appPricePoint,territory"})
section("manual prices", prices and [p["relationships"] for p in prices["data"]] or "none")
base = get(f"/apps/{app_id}/appPriceSchedule/baseTerritory")
section("price base territory", base and base["data"] and base["data"]["id"])
points = prices and [i for i in prices.get("included", []) if i["type"] == "appPricePoints"]
section("price points", points and [p["attributes"] for p in points] or "none")

avail = get(f"/apps/{app_id}/appAvailabilityV2")
if avail and avail.get("data"):
    aid = avail["data"]["id"]
    section("availability", avail["data"]["attributes"])
    on, off, url = [], [], f"/appAvailabilities/{aid}/territoryAvailabilities"
    query = {"limit": 200, "include": "territory"}
    page = get(url, query, version="v2")
    for t in (page or {}).get("data", []):
        terr = t["relationships"]["territory"]["data"]["id"]
        (on if t["attributes"].get("available") else off).append(terr)
    section("territories", {"available": len(on), "unavailable": len(off), "TUR": "TUR" in on, "USA": "USA" in on,
        "EU available": sorted(EU & set(on))})
else:
    section("availability", "not set")
