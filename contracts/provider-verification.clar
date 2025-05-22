;; Patient Verification Contract
;; Manages participant identities in the remote monitoring system

(define-data-var admin principal tx-sender)

;; Patient status: 0 = registered, 1 = active, 2 = inactive
(define-map patients
  { patient-id: principal }
  {
    name-hash: (buff 32), ;; Hash of patient name for privacy
    consent-provided: bool,
    status: uint,
    registration-time: uint,
    assigned-provider: (optional principal)
  }
)

;; Consent records for specific data usage
(define-map consent-records
  { patient-id: principal, purpose: (string-utf8 50) }
  {
    granted: bool,
    timestamp: uint
  }
)

;; Register a new patient
(define-public (register-patient (name-hash (buff 32)))
  (let ((patient-exists (is-some (map-get? patients { patient-id: tx-sender }))))
    (asserts! (not patient-exists) (err u1)) ;; Error 1: Patient already registered
    (ok (map-set patients
      { patient-id: tx-sender }
      {
        name-hash: name-hash,
        consent-provided: false,
        status: u0,
        registration-time: block-height,
        assigned-provider: none
      }
    ))
  )
)

;; Provide general consent for monitoring
(define-public (provide-consent)
  (let ((patient-data (map-get? patients { patient-id: tx-sender })))
    (asserts! (is-some patient-data) (err u3)) ;; Error 3: Patient not found
    (ok (map-set patients
      { patient-id: tx-sender }
      (merge (unwrap-panic patient-data)
        {
          consent-provided: true,
          status: u1 ;; Set to active
        }
      )
    ))
  )
)

;; Provide specific consent for data usage
(define-public (provide-specific-consent (purpose (string-utf8 50)))
  (let ((patient-data (map-get? patients { patient-id: tx-sender })))
    (asserts! (is-some patient-data) (err u3)) ;; Error 3: Patient not found
    (ok (map-set consent-records
      { patient-id: tx-sender, purpose: purpose }
      {
        granted: true,
        timestamp: block-height
      }
    ))
  )
)

;; Revoke specific consent
(define-public (revoke-specific-consent (purpose (string-utf8 50)))
  (let ((patient-data (map-get? patients { patient-id: tx-sender })))
    (asserts! (is-some patient-data) (err u3)) ;; Error 3: Patient not found
    (ok (map-set consent-records
      { patient-id: tx-sender, purpose: purpose }
      {
        granted: false,
        timestamp: block-height
      }
    ))
  )
)

;; Revoke all consent and deactivate account
(define-public (revoke-all-consent)
  (let ((patient-data (map-get? patients { patient-id: tx-sender })))
    (asserts! (is-some patient-data) (err u3)) ;; Error 3: Patient not found
    (ok (map-set patients
      { patient-id: tx-sender }
      (merge (unwrap-panic patient-data)
        {
          consent-provided: false,
          status: u2 ;; Set to inactive
        }
      )
    ))
  )
)

;; Assign provider to patient (can be done by admin or patient)
(define-public (assign-provider (patient-id principal) (provider-id principal))
  (let (
    (patient-data (map-get? patients { patient-id: patient-id }))
    (is-admin (is-eq tx-sender (var-get admin)))
    (is-patient (is-eq tx-sender patient-id))
  )
    (asserts! (or is-admin is-patient) (err u2)) ;; Error 2: Not authorized
    (asserts! (is-some patient-data) (err u3)) ;; Error 3: Patient not found
    (ok (map-set patients
      { patient-id: patient-id }
      (merge (unwrap-panic patient-data) { assigned-provider: (some provider-id) })
    ))
  )
)

;; Check if patient has provided consent
(define-read-only (has-consent (patient-id principal))
  (let ((patient-data (map-get? patients { patient-id: patient-id })))
    (if (is-some patient-data)
      (get consent-provided (unwrap-panic patient-data))
      false
    )
  )
)

;; Check if patient has provided specific consent
(define-read-only (has-specific-consent (patient-id principal) (purpose (string-utf8 50)))
  (let ((consent-data (map-get? consent-records { patient-id: patient-id, purpose: purpose })))
    (if (is-some consent-data)
      (get granted (unwrap-panic consent-data))
      false
    )
  )
)

;; Get patient details (only available to the patient or their assigned provider)
(define-read-only (get-patient-details (patient-id principal))
  (let (
    (patient-data (map-get? patients { patient-id: patient-id }))
    (is-admin (is-eq tx-sender (var-get admin)))
    (is-patient (is-eq tx-sender patient-id))
    (is-provider (and
      (is-some patient-data)
      (is-some (get assigned-provider (unwrap-panic patient-data)))
      (is-eq tx-sender (unwrap-panic (get assigned-provider (unwrap-panic patient-data))))
    ))
  )
    (if (or is-admin is-patient is-provider)
      patient-data
      none
    )
  )
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Error 2: Not authorized
    (ok (var-set admin new-admin))
  )
)
