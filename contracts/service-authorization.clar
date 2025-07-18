;; Service Access Authorization Contract
;; Enables refugee aid and benefits access

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-ACCESS-EXPIRED (err u203))
(define-constant ERR-IDENTITY-NOT-VERIFIED (err u204))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map service-providers
  { provider: principal }
  { is-authorized: bool, organization: (string-ascii 100), services: (list 10 (string-ascii 50)) }
)

(define-map service-authorizations
  { beneficiary: principal, service-type: (string-ascii 50) }
  {
    identity-id: uint,
    authorized-by: principal,
    granted-at: uint,
    expires-at: uint,
    usage-count: uint,
    max-usage: uint,
    is-active: bool
  }
)

(define-map service-usage
  { beneficiary: principal, service-type: (string-ascii 50), usage-id: uint }
  { used-at: uint, provider: principal, notes: (string-ascii 200) }
)

;; Data variables
(define-data-var next-usage-id uint u1)

;; Service provider management
(define-public (add-service-provider
  (provider principal)
  (organization (string-ascii 100))
  (services (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len services) u0) ERR-INVALID-INPUT)
    (ok (map-set service-providers
      { provider: provider }
      { is-authorized: true, organization: organization, services: services }))
  )
)

(define-public (remove-service-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set service-providers
      { provider: provider }
      { is-authorized: false, organization: "", services: (list) }))
  )
)

;; Grant service access
(define-public (grant-access
  (beneficiary principal)
  (service-type (string-ascii 50))
  (identity-id uint)
  (duration-blocks uint)
  (max-usage uint))
  (let
    (
      (provider-info (map-get? service-providers { provider: tx-sender }))
    )
    (asserts! (is-some provider-info) ERR-NOT-AUTHORIZED)
    (asserts! (get is-authorized (unwrap-panic provider-info)) ERR-NOT-AUTHORIZED)
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)
    (asserts! (> max-usage u0) ERR-INVALID-INPUT)

    ;; Check if identity is verified (would need to call identity contract in real implementation)
    ;; For now, we assume identity-id > 0 means verified
    (asserts! (> identity-id u0) ERR-IDENTITY-NOT-VERIFIED)

    (map-set service-authorizations
      { beneficiary: beneficiary, service-type: service-type }
      {
        identity-id: identity-id,
        authorized-by: tx-sender,
        granted-at: block-height,
        expires-at: (+ block-height duration-blocks),
        usage-count: u0,
        max-usage: max-usage,
        is-active: true
      }
    )

    (ok true)
  )
)

;; Use service
(define-public (use-service
  (beneficiary principal)
  (service-type (string-ascii 50))
  (notes (string-ascii 200)))
  (let
    (
      (provider-info (map-get? service-providers { provider: tx-sender }))
      (auth-info (map-get? service-authorizations { beneficiary: beneficiary, service-type: service-type }))
      (usage-id (var-get next-usage-id))
    )
    (asserts! (is-some provider-info) ERR-NOT-AUTHORIZED)
    (asserts! (get is-authorized (unwrap-panic provider-info)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some auth-info) ERR-NOT-FOUND)

    (let
      (
        (current-auth (unwrap-panic auth-info))
      )
      (asserts! (get is-active current-auth) ERR-NOT-FOUND)
      (asserts! (< block-height (get expires-at current-auth)) ERR-ACCESS-EXPIRED)
      (asserts! (< (get usage-count current-auth) (get max-usage current-auth)) ERR-ACCESS-EXPIRED)

      ;; Record usage
      (map-set service-usage
        { beneficiary: beneficiary, service-type: service-type, usage-id: usage-id }
        { used-at: block-height, provider: tx-sender, notes: notes }
      )

      ;; Update usage count
      (map-set service-authorizations
        { beneficiary: beneficiary, service-type: service-type }
        (merge current-auth { usage-count: (+ (get usage-count current-auth) u1) })
      )

      (var-set next-usage-id (+ usage-id u1))
      (ok usage-id)
    )
  )
)

;; Revoke access
(define-public (revoke-access (beneficiary principal) (service-type (string-ascii 50)))
  (let
    (
      (auth-info (map-get? service-authorizations { beneficiary: beneficiary, service-type: service-type }))
    )
    (asserts! (is-some auth-info) ERR-NOT-FOUND)
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get authorized-by (unwrap-panic auth-info)))) ERR-NOT-AUTHORIZED)

    (map-set service-authorizations
      { beneficiary: beneficiary, service-type: service-type }
      (merge (unwrap-panic auth-info) { is-active: false })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-service-authorization (beneficiary principal) (service-type (string-ascii 50)))
  (map-get? service-authorizations { beneficiary: beneficiary, service-type: service-type })
)

(define-read-only (is-access-valid (beneficiary principal) (service-type (string-ascii 50)))
  (match (map-get? service-authorizations { beneficiary: beneficiary, service-type: service-type })
    auth-info (and
                (get is-active auth-info)
                (< block-height (get expires-at auth-info))
                (< (get usage-count auth-info) (get max-usage auth-info)))
    false
  )
)

(define-read-only (get-service-provider (provider principal))
  (map-get? service-providers { provider: provider })
)

(define-read-only (get-service-usage (beneficiary principal) (service-type (string-ascii 50)) (usage-id uint))
  (map-get? service-usage { beneficiary: beneficiary, service-type: service-type, usage-id: usage-id })
)
