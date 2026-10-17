#!/usr/bin/env python3
"""Validate a rendered/merged Android manifest for Phoenix Android components."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from xml.etree import ElementTree

ANDROID = "{http://schemas.android.com/apk/res/android}"
PROVIDER = "quack.fnf.phoenix.android.PhoenixDocumentsProvider"
LEGACY_PROVIDER = "org.haxe.lime.StorageProvider"
DOCUMENTS_ACTION = "android.content.action.DOCUMENTS_PROVIDER"
MEDIA_SERVICE = "quack.fnf.phoenix.android.PhoenixMediaService"
MEDIA_ACTIONS = {
    "androidx.media3.session.MediaSessionService",
    "android.media.browse.MediaBrowserService",
}
MEDIA_PERMISSIONS = {
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
}


def check_media_service(root: ElementTree.Element, application: ElementTree.Element, path: Path, expectation: str) -> None:
    services = [
        service
        for service in application.findall("service")
        if service.attrib.get(ANDROID + "name") == MEDIA_SERVICE
    ]
    if expectation == "ignore":
        return
    if expectation == "absent":
        if services:
            raise AssertionError(f"{path}: Media3 service is present despite being expected absent")
        return

    if len(services) != 1:
        raise AssertionError(f"{path}: expected one Phoenix Media3 service, found {len(services)}")
    service = services[0]
    if service.attrib.get(ANDROID + "exported") != "true":
        raise AssertionError(f"{path}: Media3 service must be exported for system media clients")

    service_types = service.attrib.get(ANDROID + "foregroundServiceType", "").split("|")
    if "mediaPlayback" not in service_types:
        raise AssertionError(
            f"{path}: Media3 service foregroundServiceType={service.attrib.get(ANDROID + 'foregroundServiceType')!r}, "
            "expected mediaPlayback"
        )

    actions = {
        action.attrib.get(ANDROID + "name")
        for action in service.findall("intent-filter/action")
    }
    missing_actions = MEDIA_ACTIONS - actions
    if missing_actions:
        raise AssertionError(f"{path}: Media3 service is missing actions {sorted(missing_actions)!r}")

    permissions = {
        permission.attrib.get(ANDROID + "name")
        for permission in root
        if permission.tag in {"uses-permission", "uses-permission-sdk-23"}
    }
    missing_permissions = MEDIA_PERMISSIONS - permissions
    if missing_permissions:
        raise AssertionError(f"{path}: Media3 service is missing permissions {sorted(missing_permissions)!r}")


def check_manifest(
    path: Path,
    expect_provider: bool,
    minimum_sdk: int,
    target_sdk: int,
    media_service: str = "ignore",
) -> None:
    root = ElementTree.parse(path).getroot()
    application = root.find("application")
    if application is None:
        raise AssertionError(f"{path}: missing <application>")

    providers = [
        provider
        for provider in application.findall("provider")
        if provider.attrib.get(ANDROID + "name") == PROVIDER
    ]
    if expect_provider:
        if len(providers) != 1:
            raise AssertionError(f"{path}: expected one Phoenix provider, found {len(providers)}")
        provider = providers[0]
        expected = {
            "authorities": ".documentsprovider",
            "exported": "true",
            "grantUriPermissions": "true",
            "permission": "android.permission.MANAGE_DOCUMENTS",
        }
        for attribute, suffix_or_value in expected.items():
            actual = provider.attrib.get(ANDROID + attribute)
            if attribute == "authorities":
                if actual is None or not actual.endswith(suffix_or_value):
                    raise AssertionError(f"{path}: unexpected provider authority {actual!r}")
            elif actual != suffix_or_value:
                raise AssertionError(f"{path}: android:{attribute}={actual!r}, expected {suffix_or_value!r}")
        actions = {
            action.attrib.get(ANDROID + "name")
            for action in provider.findall("intent-filter/action")
        }
        if DOCUMENTS_ACTION not in actions:
            raise AssertionError(f"{path}: provider is missing the DocumentsProvider intent action")
    elif providers:
        raise AssertionError(f"{path}: provider is present despite SHARE_FILES being disabled")

    legacy = [
        provider
        for provider in application.findall("provider")
        if provider.attrib.get(ANDROID + "name") == LEGACY_PROVIDER
    ]
    if legacy:
        raise AssertionError(f"{path}: the replaced Lime StorageProvider is also registered")

    uses_sdk = root.find("uses-sdk")
    if uses_sdk is None:
        raise AssertionError(f"{path}: merged manifest is missing <uses-sdk>")
    actual_min = uses_sdk.attrib.get(ANDROID + "minSdkVersion")
    actual_target = uses_sdk.attrib.get(ANDROID + "targetSdkVersion")
    if actual_min != str(minimum_sdk):
        raise AssertionError(f"{path}: minSdkVersion={actual_min!r}, expected {minimum_sdk}")
    if actual_target != str(target_sdk):
        raise AssertionError(f"{path}: targetSdkVersion={actual_target!r}, expected {target_sdk}")

    check_media_service(root, application, path, media_service)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="Rendered/merged AndroidManifest.xml")
    parser.add_argument("--provider", choices=("present", "absent"), required=True)
    parser.add_argument("--media-service", choices=("present", "absent", "ignore"), default="ignore")
    parser.add_argument("--minimum-sdk", type=int, required=True)
    parser.add_argument("--target-sdk", type=int, required=True)
    args = parser.parse_args()

    try:
        check_manifest(
            args.manifest,
            expect_provider=args.provider == "present",
            minimum_sdk=args.minimum_sdk,
            target_sdk=args.target_sdk,
            media_service=args.media_service,
        )
    except (OSError, ElementTree.ParseError, AssertionError) as error:
        print(f"Android manifest check failed: {error}", file=sys.stderr)
        return 1

    provider_state = "registered" if args.provider == "present" else "absent"
    media_state = "ignored" if args.media_service == "ignore" else args.media_service
    print(
        f"Android manifest OK: PhoenixDocumentsProvider is {provider_state}; "
        f"PhoenixMediaService is {media_state}; minSdk={args.minimum_sdk}, "
        f"targetSdk={args.target_sdk} ({args.manifest})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
