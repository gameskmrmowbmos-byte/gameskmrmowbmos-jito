# Project overview

## Purpose

Matka Management Software is an internal, demo-only system for educational
record management. Administrators configure users and markets. Operators enter
manual records for assigned active markets. Administrators can publish manually
prepared demo results and inspect reports and audit history.

The application deliberately omits deposits, withdrawals, wallets, payment
gateways, winnings, payouts, public betting endpoints, advertisements, and
automated gambling functions.

## Roles

### Administrator

Administrators manage operators, markets, all entries, demo result publication,
reports, settings, CSV export, audit logs, and login history.

### Operator

Operators can work only with assigned active markets. They create manual
entries, edit permitted records before the configured cutoff, review their own
records, read published results, view basic reports, and change their password.

## Main data flow

1. A user signs in.
2. The backend verifies account status, password, rate limits, and lock state.
3. The API returns a short-lived access token and rotating refresh session.
4. The Flutter router exposes pages allowed by the user's role.
5. Every protected API call independently verifies the access token, account
   status, role, ownership, and market assignment.
6. Important mutations generate an audit record.

## Supported platforms

- Android
- iOS
- Windows desktop
- Web

The same Flutter feature code and API contract are reused on every platform.

