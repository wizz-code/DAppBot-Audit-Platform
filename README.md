# DAppBot Audit Platform

A decentralized bounty platform for community-driven code audits of AI-powered dApps with on-chain dispute resolution.

## Overview

DAppBot Audit Platform connects developers with security auditors through smart contract-managed bounties. Auditors identify vulnerabilities and earn rewards, with disputes resolved transparently on-chain.

## Features

- **Bounty Creation**: Developers post audit bounties with rewards
- **Audit Submission**: Security researchers submit findings
- **Reward Distribution**: Automated payment for valid findings
- **Reputation System**: Track auditor performance on-chain
- **Dispute Resolution**: On-chain arbitration for contested audits
- **Transparency**: All audits and disputes publicly verifiable

## Contract Functions

### Public Functions

- `create-bounty`: Post a new audit bounty
- `submit-audit`: Submit security findings for a bounty
- `reward-auditor`: Pay auditor for valid findings
- `resolve-bounty`: Mark bounty as complete
- `create-dispute`: Contest an audit result
- `resolve-dispute`: Arbitrate dispute (owner only)

### Read-Only Functions

- `get-bounty`: Retrieve bounty details
- `get-audit`: Get audit submission info
- `get-dispute`: View dispute information
- `get-auditor-reputation`: Check auditor's track record
- `get-bounty-count`: Total bounties created
- `get-audit-count`: Total audits submitted

## Getting Started
```bash
clarinet contract new dappbot-audit
clarinet check
clarinet test
```

## Workflow

1. Developer creates bounty with reward and code hash
2. Auditors review code and submit findings
3. Developer reviews findings and rewards valid submissions
4. Disputes can be raised and resolved by arbiter
5. Auditor reputation increases with successful audits