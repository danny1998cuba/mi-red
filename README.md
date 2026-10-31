# Mi Red

**Offline-first Android application for local network customer and billing management.**

Mi Red is a lightweight Android application built with Flutter to help small local internet service providers manage their customers, network devices, monthly subscriptions, payments, and reminders without relying on a server or an internet connection.

Designed with simplicity and usability in mind, Mi Red combines a modern interface with reliable local persistence and encrypted data backups.

## Features

- **Customer management:** Create, edit, search, archive, and reactivate customers.
- **Network devices:** Manage customer equipment with free-text device types, MAC addresses and IPv4/IPv6 information.
- **Monthly billing:** Track billing periods, individual customer fees, outstanding charges, and payment history.
- **Payment management:** Register payments, void transactions, and correct eligible outstanding charges.
- **Dashboard:** Monitor active customers, collections, outstanding balances, and accounts requiring attention.
- **WhatsApp integration:** Prepare individual payment reminders and share billing reports.
- **Local notifications:** Optional reminders for outstanding payments and potential service suspensions.
- **Encrypted backups:** Password-protected backup and restoration using AES-256-GCM.
- **Appearance:** Light, dark, and system themes with a modern, responsive interface.
- **Fully offline:** Customer and financial data remain stored locally on the device.

## Tech Stack

- Flutter & Dart
- Forui, Material and Lucide
- Riverpod
- go_router
- Drift & SQLite
- AES-256-GCM encrypted backups
- Android native integrations

## Privacy & Data

Mi Red does not require an account, external database, cloud service, or backend server.

Application data is stored locally. Users are responsible for keeping their encrypted backups and passwords safe.

SQLite schema 3 supports free-text device types and migrates existing schema 1/2 databases without changing their records. The encrypted `.miredbk` format remains version 1: this app imports schema 2 and 3 backups, and exports schema 3. Older app versions cannot import new schema 3 backups. See [device type change report](docs/DEVICE_TYPE_TEXT_REPORT.md).

External communication features, such as WhatsApp, may require an internet connection.

## Platform

- Android 7.0+ (API 24)
- Distributed as an installable APK
- No Google Play installation required

## Developer

Developed by **[CoreX4Dev](https://corex4dev.com)**.

**Version:** 1.0.1 (Android build 2)

© 2026 CoreX4Dev.
