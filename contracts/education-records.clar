;; Education Record Preservation Contract
;; Maintains academic history during displacement

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-ALREADY-EXISTS (err u503))
(define-constant ERR-INVALID-GRADE (err u504))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map education-records
  { record-id: uint }
  {
    identity-id: uint,
    institution-hash: (string-ascii 64),
    degree-type: (string-ascii 50),
    field-of-study: (string-ascii 100),
    start-date: uint,
    end-date: uint,
    grade-average: uint,
    credits-earned: uint,
    is-completed: bool,
    transcript-hash: (string-ascii 64),
    verified-by: principal,
    is-verified: bool,
    created-at: uint
  }
)

(define-map certifications
  { cert-id: uint }
  {
    identity-id: uint,
    certification-name: (string-ascii 100),
    issuing-body: (string-ascii 100),
    issued-date: uint,
    expiry-date: uint,
    certificate-hash: (string-ascii 64),
    skill-areas: (string-ascii 200),
    is-active: bool,
    verified-by: principal
  }
)

(define-map authorized-institutions
  { institution: principal }
  { is-authorized: bool, name: (string-ascii 100), country: (string-ascii 50) }
)

(define-map skill-assessments
  { assessment-id: uint }
  {
    identity-id: uint,
    skill-area: (string-ascii 100),
    proficiency-level: uint,
    assessed-by: principal,
    assessed-at: uint,
    assessment-notes: (string-ascii 200)
  }
)

;; Data variables
(define-data-var next-record-id uint u1)
(define-data-var next-cert-id uint u1)
(define-data-var next-assessment-id uint u1)

;; Institution management
(define-public (add-authorized-institution
  (institution principal)
  (name (string-ascii 100))
  (country (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (ok (map-set authorized-institutions
      { institution: institution }
      { is-authorized: true, name: name, country: country }))
  )
)

;; Add education record
(define-public (add-education-record
  (identity-id uint)
  (institution-hash (string-ascii 64))
  (degree-type (string-ascii 50))
  (field-of-study (string-ascii 100))
  (start-date uint)
  (end-date uint)
  (grade-average uint)
  (credits-earned uint)
  (is-completed bool)
  (transcript-hash (string-ascii 64)))
  (let
    (
      (record-id (var-get next-record-id))
    )
    (asserts! (> identity-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len institution-hash) u0) ERR-INVALID-INPUT)
    (asserts! (> (len degree-type) u0) ERR-INVALID-INPUT)
    (asserts! (<= start-date end-date) ERR-INVALID-INPUT)
    (asserts! (<= grade-average u100) ERR-INVALID-GRADE)

    (map-set education-records
      { record-id: record-id }
      {
        identity-id: identity-id,
        institution-hash: institution-hash,
        degree-type: degree-type,
        field-of-study: field-of-study,
        start-date: start-date,
        end-date: end-date,
        grade-average: grade-average,
        credits-earned: credits-earned,
        is-completed: is-completed,
        transcript-hash: transcript-hash,
        verified-by: tx-sender,
        is-verified: false,
        created-at: block-height
      }
    )

    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

;; Add certification
(define-public (add-certification
  (identity-id uint)
  (certification-name (string-ascii 100))
  (issuing-body (string-ascii 100))
  (issued-date uint)
  (expiry-date uint)
  (certificate-hash (string-ascii 64))
  (skill-areas (string-ascii 200)))
  (let
    (
      (cert-id (var-get next-cert-id))
    )
    (asserts! (> identity-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len certification-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len issuing-body) u0) ERR-INVALID-INPUT)
    (asserts! (<= issued-date expiry-date) ERR-INVALID-INPUT)

    (map-set certifications
      { cert-id: cert-id }
      {
        identity-id: identity-id,
        certification-name: certification-name,
        issuing-body: issuing-body,
        issued-date: issued-date,
        expiry-date: expiry-date,
        certificate-hash: certificate-hash,
        skill-areas: skill-areas,
        is-active: true,
        verified-by: tx-sender
      }
    )

    (var-set next-cert-id (+ cert-id u1))
    (ok cert-id)
  )
)

;; Verify education record (by authorized institutions)
(define-public (verify-education-record (record-id uint))
  (let
    (
      (institution-info (map-get? authorized-institutions { institution: tx-sender }))
      (record-info (map-get? education-records { record-id: record-id }))
    )
    (asserts! (is-some institution-info) ERR-NOT-AUTHORIZED)
    (asserts! (get is-authorized (unwrap-panic institution-info)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some record-info) ERR-NOT-FOUND)

    (map-set education-records
      { record-id: record-id }
      (merge (unwrap-panic record-info) { is-verified: true })
    )

    (ok true)
  )
)

;; Add skill assessment
(define-public (add-skill-assessment
  (identity-id uint)
  (skill-area (string-ascii 100))
  (proficiency-level uint)
  (assessment-notes (string-ascii 200)))
  (let
    (
      (assessment-id (var-get next-assessment-id))
      (institution-info (map-get? authorized-institutions { institution: tx-sender }))
    )
    (asserts! (is-some institution-info) ERR-NOT-AUTHORIZED)
    (asserts! (get is-authorized (unwrap-panic institution-info)) ERR-NOT-AUTHORIZED)
    (asserts! (> identity-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len skill-area) u0) ERR-INVALID-INPUT)
    (asserts! (<= proficiency-level u10) ERR-INVALID-INPUT)

    (map-set skill-assessments
      { assessment-id: assessment-id }
      {
        identity-id: identity-id,
        skill-area: skill-area,
        proficiency-level: proficiency-level,
        assessed-by: tx-sender,
        assessed-at: block-height,
        assessment-notes: assessment-notes
      }
    )

    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Update record completion status
(define-public (update-completion-status (record-id uint) (is-completed bool))
  (let
    (
      (record-info (map-get? education-records { record-id: record-id }))
    )
    (asserts! (is-some record-info) ERR-NOT-FOUND)
    (asserts! (is-eq tx-sender (get verified-by (unwrap-panic record-info))) ERR-NOT-AUTHORIZED)

    (map-set education-records
      { record-id: record-id }
      (merge (unwrap-panic record-info) { is-completed: is-completed })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-education-record (record-id uint))
  (map-get? education-records { record-id: record-id })
)

(define-read-only (get-certification (cert-id uint))
  (map-get? certifications { cert-id: cert-id })
)

(define-read-only (is-certification-valid (cert-id uint))
  (match (map-get? certifications { cert-id: cert-id })
    cert-info (and
                (get is-active cert-info)
                (< block-height (get expiry-date cert-info)))
    false
  )
)

(define-read-only (get-skill-assessment (assessment-id uint))
  (map-get? skill-assessments { assessment-id: assessment-id })
)

(define-read-only (get-authorized-institution (institution principal))
  (map-get? authorized-institutions { institution: institution })
)

(define-read-only (get-next-record-id)
  (var-get next-record-id)
)
