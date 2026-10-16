#!/usr/bin/env python3
"""Short-lived App Store distribution signing for CI, through the App Store Connect API.

  setup <out_dir> <bundle_id>...   creates a distribution certificate from a fresh key, an App Store
                                   profile per bundle ID (registering missing IDs), and writes
                                   key.pem, cert.cer, <bundle_id>.mobileprovision and state.json to out_dir.
                                   <bundle_id>+CAPABILITY (e.g. +APPLE_ID_AUTH) also turns that
                                   capability on for the ID first, so the profile carries it
  cleanup <out_dir>                revokes the certificate and deletes the profiles from state.json

Why not Xcode's cloud-managed signing: when the account holder's name has non-ASCII letters
(“ERDOĞAN”), Xcode writes the certificate name into the designated requirement in decomposed
Unicode, the signature no longer satisfies its own requirement, and App Store Connect rejects
the upload with error 90035. Signing locally with codesign avoids that. Revoking the certificate
afterwards keeps the team under Apple's certificate limit and does not affect uploaded builds.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH, plus `pip install pyjwt cryptography`.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

API = "https://api.appstoreconnect.apple.com/v1"
PROFILE_PREFIX = "Derin CI "


def token():
    key = open(os.environ["ASC_KEY_PATH"]).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method, path, body=None, query=None):
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} failed: {e.code} {e.read().decode(errors='replace')}")


def bundle_id(identifier):
    found = call("GET", "/bundleIds", query={"filter[identifier]": identifier, "limit": 200})["data"]
    for item in found:
        if item["attributes"]["identifier"] == identifier:
            return item["id"]
    print(f"Registering bundle ID {identifier}")
    name = "Derin " + identifier.rsplit(".", 1)[-1] if identifier.count(".") > 2 else "Derin"
    created = call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": name.replace("-", " "), "platform": "IOS"}}})
    return created["data"]["id"]


CAPABILITY_SETTINGS = {
    "APPLE_ID_AUTH": [{"key": "APPLE_ID_AUTH_APP_CONSENT", "options": [{"key": "PRIMARY_APP_CONSENT"}]}],
}


def ensure_capability(bundle_pk, capability):
    caps = call("GET", f"/bundleIds/{bundle_pk}/bundleIdCapabilities", query={"limit": 200})["data"]
    if any(c["attributes"]["capabilityType"] == capability for c in caps):
        return
    print(f"Enabling {capability}")
    attributes = {"capabilityType": capability}
    if capability in CAPABILITY_SETTINGS:
        attributes["settings"] = CAPABILITY_SETTINGS[capability]
    call("POST", "/bundleIdCapabilities", {"data": {
        "type": "bundleIdCapabilities", "attributes": attributes,
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_pk}}}}})


def delete_profiles(name):
    for item in call("GET", "/profiles", query={"filter[name]": name, "limit": 200})["data"]:
        if item["attributes"]["name"] == name:
            call("DELETE", f"/profiles/{item['id']}")


def setup(out_dir, identifiers):
    os.makedirs(out_dir, exist_ok=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Derin CI")]))
           .sign(key, hashes.SHA256()))
    with open(os.path.join(out_dir, "key.pem"), "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                                  serialization.NoEncryption()))

    cert = call("POST", "/certificates", {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION",
        "csrContent": csr.public_bytes(serialization.Encoding.PEM).decode()}}})["data"]
    state = {"certificate": cert["id"], "profiles": []}
    with open(os.path.join(out_dir, "state.json"), "w") as f:
        json.dump(state, f)
    with open(os.path.join(out_dir, "cert.cer"), "wb") as f:
        f.write(base64.b64decode(cert["attributes"]["certificateContent"]))

    for arg in identifiers:
        identifier, *capabilities = arg.split("+")
        bundle_pk = bundle_id(identifier)
        for capability in capabilities:
            ensure_capability(bundle_pk, capability)
        name = PROFILE_PREFIX + identifier
        delete_profiles(name)
        profile = call("POST", "/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_pk}},
                "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]}}}})["data"]
        state["profiles"].append(profile["id"])
        with open(os.path.join(out_dir, "state.json"), "w") as f:
            json.dump(state, f)
        with open(os.path.join(out_dir, identifier + ".mobileprovision"), "wb") as f:
            f.write(base64.b64decode(profile["attributes"]["profileContent"]))
        print(f"Profile “{name}” ready")


def cleanup(out_dir):
    path = os.path.join(out_dir, "state.json")
    if not os.path.exists(path):
        return
    state = json.load(open(path))
    for profile in state["profiles"]:
        call("DELETE", f"/profiles/{profile}")
    call("DELETE", f"/certificates/{state['certificate']}")
    print("Revoked the CI certificate and deleted its profiles")


if __name__ == "__main__":
    if sys.argv[1] == "setup":
        setup(sys.argv[2], sys.argv[3:])
    elif sys.argv[1] == "cleanup":
        cleanup(sys.argv[2])
    else:
        sys.exit(__doc__)
