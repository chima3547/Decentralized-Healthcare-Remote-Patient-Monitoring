;; Provider Verification Contract
;; Validates healthcare entities in the remote monitoring system

(define-data-var admin principal tx-sender)

;; Provider status: 0 = unverified, 1 = verified, 2 = suspended
(define-map providers
  { provider-id: principal }
  {
    name: (string-utf8 100),
    license-number: (string-utf8 50),
    specialty: (string-utf8 50),
    status: uint,
    registration-time: uint
  }
)

;; Register a new healthcare provider
(define-public (register-provider (name (string-utf8 100)) (license-number (string-utf8 50)) (specialty (string-utf8 50)))
  (let ((provider-exists (is-some (map-get? providers { provider-id: tx-sender }))))
    (asserts! (not provider-exists) (err u1)) ;; Error 1: Provider already registered
    (ok (map-set providers
      { provider-id: tx-sender }
      {
        name: name,
        license-number: license-number,
        specialty: specialty,
        status: u0, ;; Initially unverified
        registration-time: block-height
      }
    ))
  )
)

;; Verify a provider (admin only)
(define-public (verify-provider (provider-id principal))
  (let ((provider-data (map-get? providers { provider-id: provider-id })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Error 2: Not authorized
    (asserts! (is-some provider-data) (err u3)) ;; Error 3: Provider not found
    (ok (map-set providers
      { provider-id: provider-id }
      (merge (unwrap-panic provider-data) { status: u1 })
    ))
  )
)

;; Suspend a provider (admin only)
(define-public (suspend-provider (provider-id principal))
  (let ((provider-data (map-get? providers { provider-id: provider-id })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Error 2: Not authorized
    (asserts! (is-some provider-data) (err u3)) ;; Error 3: Provider not found
    (ok (map-set providers
      { provider-id: provider-id }
      (merge (unwrap-panic provider-data) { status: u2 })
    ))
  )
)

;; Check if a provider is verified
(define-read-only (is-provider-verified (provider-id principal))
  (let ((provider-data (map-get? providers { provider-id: provider-id })))
    (if (is-some provider-data)
      (is-eq (get status (unwrap-panic provider-data)) u1)
      false
    )
  )
)

;; Get provider details
(define-read-only (get-provider-details (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Error 2: Not authorized
    (ok (var-set admin new-admin))
  )
)
