;; Token Factory Contract - Creates and manages custom tokens for time-locking
;; Enhanced with comprehensive security validations

;; Error constants
(define-constant ERR-NOT-OWNER (err u200))
(define-constant ERR-TOKEN-EXISTS (err u201))
(define-constant ERR-INVALID-SUPPLY (err u202))
(define-constant ERR-INSUFFICIENT-BALANCE (err u203))
(define-constant ERR-TOKEN-NOT-FOUND (err u204))
(define-constant ERR-TRANSFER-FAILED (err u205))
(define-constant ERR-INVALID-INPUT (err u206))
(define-constant ERR-SELF-TRANSFER (err u207))
(define-constant ERR-INVALID-PRINCIPAL (err u208))
(define-constant ERR-RATE-LIMIT-EXCEEDED (err u209))

;; Security constants
(define-constant MAX-SUPPLY u1000000000000000000) ;; 1 billion with 18 decimals
(define-constant MAX-TOKENS-PER-USER u50)
(define-constant BURN-ADDRESS 'SP000000000000000000002Q6VF78)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)

;; Token information
(define-map tokens 
    uint 
    {
        name: (string-ascii 32),
        symbol: (string-ascii 8),
        total-supply: uint,
        creator: principal,
        created-at: uint,
        decimals: uint
    }
)

;; Token balances
(define-map token-balances 
    { token-id: uint, owner: principal }
    uint
)

;; Token allowances for transfers
(define-map token-allowances
    { token-id: uint, owner: principal, spender: principal }
    uint
)

;; Rate limiting
(define-map user-token-count principal uint)

;; Input validation functions
(define-private (is-valid-string (str (string-ascii 32)))
    (and (> (len str) u0) (<= (len str) u32))
)

(define-private (is-valid-symbol (sym (string-ascii 8)))
    (and (> (len sym) u0) (<= (len sym) u8))
)

(define-private (is-valid-principal (addr principal))
    (and 
        (not (is-eq addr tx-sender))
        (not (is-eq addr BURN-ADDRESS))
    )
)

(define-private (is-valid-amount (amount uint))
    (and (> amount u0) (<= amount MAX-SUPPLY))
)

(define-private (is-valid-supply (supply uint))
    (and (> supply u0) (<= supply MAX-SUPPLY))
)

(define-private (is-valid-decimals (decimals uint))
    (<= decimals u18)
)

(define-private (token-exists (token-id uint))
    (is-some (map-get? tokens token-id))
)

(define-private (check-rate-limit (user principal))
    (let (
        (user-tokens (default-to u0 (map-get? user-token-count user)))
    )
        (< user-tokens MAX-TOKENS-PER-USER)
    )
)

;; Create a new token with comprehensive validation
(define-public (create-token (name (string-ascii 32)) (symbol (string-ascii 8)) (initial-supply uint) (decimals uint))
    (let (
        (token-id (var-get next-token-id))
        (user-tokens (default-to u0 (map-get? user-token-count tx-sender)))
    )
        (begin
            ;; Input validation
            (asserts! (is-valid-string name) ERR-INVALID-INPUT)
            (asserts! (is-valid-symbol symbol) ERR-INVALID-INPUT)
            (asserts! (is-valid-supply initial-supply) ERR-INVALID-SUPPLY)
            (asserts! (is-valid-decimals decimals) ERR-INVALID-INPUT)
            (asserts! (check-rate-limit tx-sender) ERR-RATE-LIMIT-EXCEEDED)
            
            ;; Create token record
            (map-set tokens token-id {
                name: name,
                symbol: symbol,
                total-supply: initial-supply,
                creator: tx-sender,
                created-at: block-height,
                decimals: decimals
            })
            
            ;; Set initial balance to creator
            (map-set token-balances 
                { token-id: token-id, owner: tx-sender }
                initial-supply
            )
            
            ;; Update rate limiting
            (map-set user-token-count tx-sender (+ user-tokens u1))
            
            ;; Increment token ID
            (var-set next-token-id (+ token-id u1))
            
            ;; Emit event
            (print {
                event: "token-created",
                token-id: token-id,
                creator: tx-sender,
                name: name,
                symbol: symbol,
                supply: initial-supply,
                decimals: decimals
            })
            
            (ok token-id)
        )
    )
)

;; Transfer tokens with validation
(define-public (transfer-token (token-id uint) (amount uint) (to principal))
    (let (
        (sender-balance (get-balance token-id tx-sender))
    )
        (begin
            ;; Input validation
            (asserts! (token-exists token-id) ERR-TOKEN-NOT-FOUND)
            (asserts! (is-valid-amount amount) ERR-INVALID-INPUT)
            (asserts! (not (is-eq to tx-sender)) ERR-SELF-TRANSFER)
            (asserts! (not (is-eq to BURN-ADDRESS)) ERR-INVALID-PRINCIPAL)
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update balances
            (map-set token-balances
                { token-id: token-id, owner: tx-sender }
                (- sender-balance amount)
            )
            
            (map-set token-balances
                { token-id: token-id, owner: to }
                (+ (get-balance token-id to) amount)
            )
            
            ;; Emit event
            (print {
                event: "token-transfer",
                token-id: token-id,
                from: tx-sender,
                to: to,
                amount: amount
            })
            
            (ok true)
        )
    )
)

;; Approve spending allowance with validation
(define-public (approve-token (token-id uint) (spender principal) (amount uint))
    (begin
        ;; Input validation
        (asserts! (token-exists token-id) ERR-TOKEN-NOT-FOUND)
        (asserts! (not (is-eq spender tx-sender)) ERR-SELF-TRANSFER)
        (asserts! (not (is-eq spender BURN-ADDRESS)) ERR-INVALID-PRINCIPAL)
        (asserts! (<= amount MAX-SUPPLY) ERR-INVALID-INPUT)
        
        (map-set token-allowances
            { token-id: token-id, owner: tx-sender, spender: spender }
            amount
        )
        
        ;; Emit event
        (print {
            event: "token-approval",
            token-id: token-id,
            owner: tx-sender,
            spender: spender,
            amount: amount
        })
        
        (ok true)
    )
)

;; Transfer from (using allowance) with validation
(define-public (transfer-from (token-id uint) (from principal) (to principal) (amount uint))
    (let (
        (allowance (get-allowance token-id from tx-sender))
        (from-balance (get-balance token-id from))
    )
        (begin
            ;; Input validation
            (asserts! (token-exists token-id) ERR-TOKEN-NOT-FOUND)
            (asserts! (is-valid-amount amount) ERR-INVALID-INPUT)
            (asserts! (not (is-eq to from)) ERR-SELF-TRANSFER)
            (asserts! (not (is-eq to BURN-ADDRESS)) ERR-INVALID-PRINCIPAL)
            (asserts! (>= allowance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (>= from-balance amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update allowance
            (map-set token-allowances
                { token-id: token-id, owner: from, spender: tx-sender }
                (- allowance amount)
            )
            
            ;; Update balances
            (map-set token-balances
                { token-id: token-id, owner: from }
                (- from-balance amount)
            )
            
            (map-set token-balances
                { token-id: token-id, owner: to }
                (+ (get-balance token-id to) amount)
            )
            
            ;; Emit event
            (print {
                event: "token-transfer-from",
                token-id: token-id,
                from: from,
                to: to,
                spender: tx-sender,
                amount: amount
            })
            
            (ok true)
        )
    )
)

;; Mint additional tokens (only creator can do this) with validation
(define-public (mint-tokens (token-id uint) (amount uint) (to principal))
    (let (
        (token-info (unwrap! (map-get? tokens token-id) ERR-TOKEN-NOT-FOUND))
        (creator (get creator token-info))
        (current-supply (get total-supply token-info))
        (new-supply (+ current-supply amount))
    )
        (begin
            ;; Input validation
            (asserts! (is-eq tx-sender creator) ERR-NOT-OWNER)
            (asserts! (is-valid-amount amount) ERR-INVALID-INPUT)
            (asserts! (not (is-eq to BURN-ADDRESS)) ERR-INVALID-PRINCIPAL)
            (asserts! (<= new-supply MAX-SUPPLY) ERR-INVALID-SUPPLY)
            
            ;; Update token info
            (map-set tokens token-id
                (merge token-info { total-supply: new-supply })
            )
            
            ;; Add to recipient balance
            (map-set token-balances
                { token-id: token-id, owner: to }
                (+ (get-balance token-id to) amount)
            )
            
            ;; Emit event
            (print {
                event: "token-mint",
                token-id: token-id,
                to: to,
                amount: amount,
                new-supply: new-supply
            })
            
            (ok true)
        )
    )
)

;; Burn tokens (reduce supply) - new security feature
(define-public (burn-tokens (token-id uint) (amount uint))
    (let (
        (token-info (unwrap! (map-get? tokens token-id) ERR-TOKEN-NOT-FOUND))
        (creator (get creator token-info))
        (current-supply (get total-supply token-info))
        (user-balance (get-balance token-id tx-sender))
    )
        (begin
            ;; Input validation
            (asserts! (is-valid-amount amount) ERR-INVALID-INPUT)
            (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (>= current-supply amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update token supply
            (map-set tokens token-id
                (merge token-info { total-supply: (- current-supply amount) })
            )
            
            ;; Reduce user balance
            (map-set token-balances
                { token-id: token-id, owner: tx-sender }
                (- user-balance amount)
            )
            
            ;; Emit event
            (print {
                event: "token-burn",
                token-id: token-id,
                burner: tx-sender,
                amount: amount,
                new-supply: (- current-supply amount)
            })
            
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-token-info (token-id uint))
    (map-get? tokens token-id)
)

(define-read-only (get-balance (token-id uint) (owner principal))
    (default-to u0 (map-get? token-balances { token-id: token-id, owner: owner }))
)

(define-read-only (get-allowance (token-id uint) (owner principal) (spender principal))
    (default-to u0 (map-get? token-allowances { token-id: token-id, owner: owner, spender: spender }))
)

(define-read-only (get-total-tokens)
    (- (var-get next-token-id) u1)
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-user-token-count (user principal))
    (default-to u0 (map-get? user-token-count user))
)

(define-read-only (get-max-supply)
    MAX-SUPPLY
)

(define-read-only (get-max-tokens-per-user)
    MAX-TOKENS-PER-USER
)
