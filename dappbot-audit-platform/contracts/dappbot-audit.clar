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

;; Read-only functions
(define-read-only (get-bounty (bounty-id uint))
  (map-get? bounties bounty-id)
)

(define-read-only (get-audit (audit-id uint))
  (map-get? audits audit-id)
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-auditor-reputation (auditor principal))
  (default-to u0 (map-get? auditor-reputation auditor))
)

(define-read-only (get-bounty-count)
  (ok (var-get bounty-count))
)

(define-read-only (get-audit-count)
  (ok (var-get audit-count))
)

(define-read-only (get-dispute-count)
  (ok (var-get dispute-count))
)

(define-read-only (is-auditor-verified (auditor principal))
  (default-to false (map-get? auditor-verified auditor))
)

(define-read-only (get-bounty-audit-count (bounty-id uint))
  (default-to u0 (map-get? bounty-auditor-count bounty-id))
)

(define-read-only (has-submitted-audit (auditor principal) (bounty-id uint))
  (default-to false (map-get? auditor-bounty-submissions { auditor: auditor, bounty-id: bounty-id }))
)

(define-read-only (get-audit-review (audit-id uint) (reviewer principal))
  (map-get? audit-reviews { audit-id: audit-id, reviewer: reviewer })
)

;; Get bounty statistics
(define-read-only (get-bounty-stats (bounty-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (total-audits (get-bounty-audit-count bounty-id))
    )
    (ok {
      developer: (get developer bounty-data),
      reward-amount: (get reward-amount bounty-data),
      resolved: (get resolved bounty-data),
      total-audits: total-audits
    })
  )
)

;; Check if bounty is active
(define-read-only (is-bounty-active (bounty-id uint))
  (match (map-get? bounties bounty-id)
    bounty-data (ok (not (get resolved bounty-data)))
    err-not-found
  )
)

;; Get auditor stats
(define-read-only (get-auditor-stats (auditor principal))
  (ok {
    reputation: (get-auditor-reputation auditor),
    verified: (is-auditor-verified auditor)
  })
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-bounty (dapp-name (string-ascii 50)) (reward-amount uint) (code-hash (buff 32)))
  (let
    (
      (bounty-id (var-get bounty-count))
    )
    (asserts! (> reward-amount u0) err-invalid-amount)
    (map-set bounties bounty-id
      {
        developer: tx-sender,
        dapp-name: dapp-name,
        reward-amount: reward-amount,
        code-hash: code-hash,
        resolved: false,
        created-at: stacks-block-height
      }
    )
    (var-set bounty-count (+ bounty-id u1))
    (ok bounty-id)
  )
)

;; #[allow(unchecked_data)]
(define-public (submit-audit (bounty-id uint) (findings-hash (buff 32)) (severity (string-ascii 20)))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (audit-id (var-get audit-count))
    )
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-set audits audit-id
      {
        bounty-id: bounty-id,
        auditor: tx-sender,
        findings-hash: findings-hash,
        severity: severity,
        rewarded: false,
        submitted-at: stacks-block-height
      }
    )
    (var-set audit-count (+ audit-id u1))
    (ok audit-id)
  )
)

(define-public (reward-auditor (audit-id uint))
  (let
    (
      (audit-data (unwrap! (map-get? audits audit-id) err-not-found))
      (bounty-data (unwrap! (map-get? bounties (get bounty-id audit-data)) err-not-found))
      (auditor (get auditor audit-data))
      (current-rep (get-auditor-reputation auditor))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (not (get rewarded audit-data)) err-already-claimed)
    (map-set audits audit-id
      (merge audit-data { rewarded: true })
    )
    (map-set auditor-reputation auditor (+ current-rep u1))
    (ok true)
  )
)

(define-public (resolve-bounty (bounty-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-set bounties bounty-id
      (merge bounty-data { resolved: true })
    )
    (ok true)
  )
)

;; Batch reward auditors
(define-public (batch-reward-auditors (audit-ids (list 10 uint)))
  (begin
    (asserts! (> (len audit-ids) u0) err-invalid-amount)
    (ok (map reward-single-auditor audit-ids))
  )
)

;; Helper for batch reward
(define-private (reward-single-auditor (audit-id uint))
  (match (map-get? audits audit-id)
    audit-data
      (match (map-get? bounties (get bounty-id audit-data))
        bounty-data
          (let
            (
              (auditor (get auditor audit-data))
              (current-rep (get-auditor-reputation auditor))
            )
            (if (and 
                  (is-eq tx-sender (get developer bounty-data))
                  (not (get rewarded audit-data)))
              (begin
                (map-set audits audit-id
                  (merge audit-data { rewarded: true })
                )
                (map-set auditor-reputation auditor (+ current-rep u1))
                true
              )
              false
            )
          )
        false
      )
    false
  )
)

;; #[allow(unchecked_data)]
(define-public (create-dispute (audit-id uint) (reason (string-ascii 200)))
  (let
    (
      (audit-data (unwrap! (map-get? audits audit-id) err-not-found))
      (dispute-id (var-get dispute-count))
    )
    (map-set disputes dispute-id
      {
        audit-id: audit-id,
        initiator: tx-sender,
        reason: reason,
        resolved: false,
        resolution: "",
        created-at: stacks-block-height
      }
    )
    (var-set dispute-count (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (resolve-dispute (dispute-id uint) (resolution (string-ascii 20)))
  (let
    (
      (dispute-data (unwrap! (map-get? disputes dispute-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get resolved dispute-data)) err-already-resolved)
    (map-set disputes dispute-id
      (merge dispute-data { resolved: true, resolution: resolution })
    )
    (ok true)
  )
)

;; Submit audit review
;; #[allow(unchecked_data)]
(define-public (submit-audit-review (audit-id uint) (rating uint) (comment-hash (buff 32)))
  (let
    (
      (audit-data (unwrap! (map-get? audits audit-id) err-not-found))
      (bounty-data (unwrap! (map-get? bounties (get bounty-id audit-data)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (<= rating u5) err-invalid-amount)
    (map-set audit-reviews { audit-id: audit-id, reviewer: tx-sender }
      { rating: rating, comment-hash: comment-hash }
    )
    (ok true)
  )
)

;; Verify auditor
;; #[allow(unchecked_data)]
(define-public (verify-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set auditor-verified auditor true)
    (ok true)
  )
)

;; Unverify auditor
;; #[allow(unchecked_data)]
(define-public (unverify-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set auditor-verified auditor false)
    (ok true)
  )
)

;; Increase auditor reputation manually
;; #[allow(unchecked_data)]
(define-public (adjust-auditor-reputation (auditor principal) (amount uint))
  (let
    (
      (current-rep (get-auditor-reputation auditor))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set auditor-reputation auditor (+ current-rep amount))
    (ok true)
  )
)

;; Decrease auditor reputation
(define-public (decrease-auditor-reputation (auditor principal) (amount uint))
  (let
    (
      (current-rep (get-auditor-reputation auditor))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= current-rep amount) err-invalid-amount)
    (map-set auditor-reputation auditor (- current-rep amount))
    (ok true)
  )
)

;; Update bounty reward
(define-public (update-bounty-reward (bounty-id uint) (new-reward uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (asserts! (> new-reward u0) err-invalid-amount)
    (map-set bounties bounty-id
      (merge bounty-data { reward-amount: new-reward })
    )
    (ok true)
  )
)

;; Cancel bounty
(define-public (cancel-bounty (bounty-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-set bounties bounty-id
      (merge bounty-data { resolved: true })
    )
    (ok true)
  )
)

;; Withdraw audit (by auditor)
(define-public (withdraw-audit (audit-id uint))
  (let
    (
      (audit-data (unwrap! (map-get? audits audit-id) err-not-found))
      (bounty-data (unwrap! (map-get? bounties (get bounty-id audit-data)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get auditor audit-data)) err-unauthorized)
    (asserts! (not (get rewarded audit-data)) err-already-claimed)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-delete audits audit-id)
    (ok true)
  )
)

;; Update audit severity
(define-public (update-audit-severity (audit-id uint) (new-severity (string-ascii 20)))
  (let
    (
      (audit-data (unwrap! (map-get? audits audit-id) err-not-found))
      (bounty-data (unwrap! (map-get? bounties (get bounty-id audit-data)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get auditor audit-data)) err-unauthorized)
    (asserts! (not (get rewarded audit-data)) err-already-claimed)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-set audits audit-id
      (merge audit-data { severity: new-severity })
    )
    (ok true)
  )
)

;; Transfer bounty ownership
(define-public (transfer-bounty (bounty-id uint) (new-developer principal))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get developer bounty-data)) err-unauthorized)
    (asserts! (not (get resolved bounty-data)) err-already-resolved)
    (map-set bounties bounty-id
      (merge bounty-data { developer: new-developer })
    )
    (ok true)
  )
)