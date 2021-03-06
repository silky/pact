;stuff
(use 'keysets)

(define-keyset 'accounts-admin-keyset
  (read-keyset "accounts-admin-keyset"))

(module accounts 'accounts-admin-keyset
  "Simple account functionality. \
\ Tables used: 'accounts        \
\ Version: 0.1                  \
\ Author: Stuart Popejoy"
  (defun create-account (address keyset ccy date)
    (insert 'accounts address
      { "balance": 0.0
      , "amount": 0.0
      , "ccy": ccy
      , "keyset": keyset
      , "date": date
      , "data": "Created account"
      }
    ))

  (defun transfer (src dest amount date)
    "transfer AMOUNT from SRC to DEST"
    ;read balance and row-level keyset from src
    (with-read 'accounts src { "balance":= src-balance
                             , "keyset" := src-ks }
      (check-balance src-balance amount)
      (with-keyset src-ks
        (with-read 'accounts dest
                   { "balance":= dest-balance }
          (update 'accounts src
                  { "balance": (- src-balance amount)
                  , "amount": (- amount)
                  , "date": (is-time date)
                  , "data": { "transfer-to": dest }
                  }
          )
          (update 'accounts dest
                  { "balance": (+ dest-balance amount)
                  , "amount": amount
                  , "date": (is-time date)
                  , "data": { "transfer-from": src }
                  }
          )))))

  (defun read-account-user (id)
    "Read data for account ID"
    (with-read 'accounts id
              { "balance":= b
              , "ccy":= c
              , "keyset" := ks }
      (with-keyset ks
        { "balance": b, "ccy": c }
        )))

  (defun read-account-admin (id)
    "Read data for account ID, admin version"
    (with-keyset 'accounts-admin-keyset
      (read 'accounts id 'balance 'ccy 'keyset 'data 'date 'amount)))


  (defun account-keys (from)
    "Get account keys after FROM txid"
    (with-keyset 'accounts-admin-keyset (keys 'accounts from)))

  (defun check-balance (balance amount)
    (enforce (<= (is-decimal amount) balance) "Insufficient funds"))

  (defun fund-account (address amount date)
    (with-keyset 'accounts-admin-keyset
      (update 'accounts address
              { "balance": (is-decimal amount)
              , "amount": amount
              , "date": (is-time date)
              , "data": "Admin account funding" }
      )))

  (defun read-all ()
    (map (read-account-admin) (keys 'accounts)))

  (defpact payment (payer payer-entity payee payee-entity amount date)
    "Debit PAYER at PAYER-ENTITY then credit PAYEE at PAYEE-ENTITY for AMOUNT on DATE"
    (step-with-rollback payer-entity
      (debit payer amount date
            { "payee": payee
            , "payee-entity": payee-entity
            , PACT_REF: (pact-txid)
            }
      )
      (credit payer amount date
             { PACT_REF: (pact-txid), "note": "rollback" }
      ))
    (step payee-entity
      (credit payee amount date
            { "payer": payer
            , "payer-entity": payer-entity
            , PACT_REF: (pact-txid)
            }
      )))

  (defun debit (acct amount date data)
    "Debit AMOUNT from ACCT balance recording DATE and DATA"
    (with-read 'accounts acct
              { "balance":= balance
              , "keyset" := ks
              }
      (check-balance balance amount)
        (with-keyset ks
          (update 'accounts acct
                { "balance": (- balance amount)
                , "amount": (- amount)
                , "date": (is-time date)
                , "data": data
                }
          ))))

 (defun credit (acct amount date data)
   "Credit AMOUNT to ACCT balance recording DATE and DATA"
   (with-read 'accounts acct
              { "balance":= balance }
     (update 'accounts acct
            { "balance": (+ balance amount)
            , "amount": amount
            , "date": (is-time date)
            , "data": data
            }
      )))

  (defconst PACT_REF "ref")

)

(create-table 'accounts 'accounts)
;done
