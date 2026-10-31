#!/usr/bin/env python3
"""Fills in what App Store Connect still needs before review, and optionally submits the version.

  asc_release.py <build number> [--submit]

Attaches the build to the version being prepared, writes the App Review contact (name, email) and notes
from appstore/review.json, declares the content rights, makes the app free, and makes it available
everywhere except the EU. The reviewer phone number is left to App Store Connect (the repo is public).
With --submit, also sends the version to App Review.
Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (see asc_signing.py).
"""
import json
import os
import sys

import asc_signing
from asc_signing import call

BUNDLE_ID = "com.beyzaerdogan.derin"
EU = {"AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL", "ITA",
      "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"}
REVIEW = json.load(open(os.path.join(os.path.dirname(__file__), "..", "appstore", "review.json")))


def all_pages(path, query):
    items, page = [], call("GET", path, query=query)
    items += page["data"]
    while page.get("links", {}).get("next"):
        page = call("GET", page["links"]["next"].replace(asc_signing.API, ""))
        items += page["data"]
    return items


def main():
    build_number, submit = sys.argv[1], "--submit" in sys.argv
    app = call("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})["data"][0]
    app_id = app["id"]
    version = call("GET", f"/apps/{app_id}/appStoreVersions",
                   query={"filter[platform]": "IOS", "filter[appStoreState]": "PREPARE_FOR_SUBMISSION"})["data"][0]
    vid = version["id"]

    build = call("GET", "/builds", query={"filter[app]": app_id, "filter[version]": build_number})["data"][0]
    call("PATCH", f"/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
    print(f"attached build {build_number}")

    detail = call("GET", f"/appStoreVersions/{vid}/appStoreReviewDetail")["data"]
    attrs = {"contactFirstName": REVIEW["firstName"], "contactLastName": REVIEW["lastName"],
             "contactEmail": REVIEW["email"], "demoAccountRequired": False, "notes": REVIEW["notes"]}
    if detail:
        call("PATCH", f"/appStoreReviewDetails/{detail['id']}", {"data": {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": attrs}})
    else:
        call("POST", "/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    print("wrote review contact and notes")

    call("PATCH", f"/apps/{app_id}", {"data": {"type": "apps", "id": app_id,
        "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"}}})
    print("declared third-party content rights")

    free = next(p for p in call("GET", f"/apps/{app_id}/appPricePoints", query={"filter[territory]": "USA", "limit": 200})["data"]
                if float(p["attributes"]["customerPrice"]) == 0)
    call("POST", "/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
            "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    print("price: free")

    territories = [t["id"] for t in all_pages("/territories", {"limit": 200})]
    asc_signing.API = asc_signing.API.replace("/v1", "/v2")
    try:
        call("POST", "/appAvailabilities", {
            "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": False}, "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]}}},
            "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": t not in EU},
                "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in territories]})
    finally:
        asc_signing.API = asc_signing.API.replace("/v2", "/v1")
    print(f"available in {len([t for t in territories if t not in EU])} territories, not in the {len(EU)} EU countries")

    if submit:
        sub = call("POST", "/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        call("POST", "/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        call("PATCH", f"/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"],
            "attributes": {"submitted": True}}})
        print("submitted for review")


if __name__ == "__main__":
    main()
