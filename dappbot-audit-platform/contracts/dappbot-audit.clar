;; DAppBot Audit Platform
;; Bounty platform for community-driven AI dApp audits

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-found (err u401))
(define-constant err-already-claimed (err u402))
(define-constant err-invalid-amount (err u403))
(define-constant err-unauthorized (err u404))
(define-constant err-already-resolved (err u405))

;; Data Variables
(define-data-var bounty-count uint u0)
(define-data-var audit-count uint u0)
(define-data-var dispute-count uint u0)

;; Data Maps
(define-map bounties uint
  {
    developer: principal,
    dapp-name: (string-ascii 50),
    reward-amount: uint,
    code-hash: (buff 32),
    resolved: bool,
    created-at: uint
  }
)

(define-map audits uint
  {
    bounty-id: uint,
    auditor: principal,
    findings-hash: (buff 32),
    severity: (string-ascii 20),
    rewarded: bool,
    submitted-at: uint
  }
)

(define-map disputes uint
  {
    audit-id: uint,
    initiator: principal,
    reason: (string-ascii 200),
    resolved: bool,
    resolution: (string-ascii 20),
    created-at: uint
  }
)

(define-map auditor-reputation principal uint)
(define-map auditor-verified principal bool)
(define-map bounty-auditor-count uint uint)
(define-map auditor-bounty-submissions { auditor: principal, bounty-id: uint } bool)
(define-map audit-reviews { audit-id: uint, reviewer: principal } { rating: uint, comment-hash: (buff 32) })