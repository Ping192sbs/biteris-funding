# Biteris Funding

**Direct borrower-to-lender application pipeline.** Real-time submission, encrypted end-to-end, signed on both ends, auditable forever.

No brokers. No middleware queues. No plaintext PII sitting in a database waiting to leak.

---

## Why this exists

The commercial lending stack is broken in three specific ways:

1. **Brokers extract 2–6% and add weeks.** They sit between borrowers and lenders, hold applications in spreadsheets, and mark up rates. The borrower pays for the privilege of waiting.
2. **Plaintext PII is everywhere.** Applications sit in CRM databases, email attachments, PDF exports. A single compromised inbox exposes thousands of borrowers.
3. **Nobody can prove what happened.** When a regulator asks "who saw this application and when," the answer is usually a shrug.

Biteris Funding is built to fix all three. It's a direct pipeline — borrower submits, matched lender receives, decision returns, disbursement fires — with cryptographic proof at every step and no plaintext payload at rest.

This repository contains the AWS infrastructure that runs it.

---

## What actually happens when a borrower applies

Walk through a single application. Every step is enforced by code in this repo.

**1. Browser-side encryption.** The borrower fills in the form. Before any byte leaves the device, each field is encrypted with a key derived from the session using Argon2id, then wrapped with AES-512-GCM. The browser sends ciphertext and a hash — nothing else.

**2. Edge.** CloudFront terminates TLS. WAFv2 inspects headers with AWS Managed Rules (Common, Known Bad Inputs, SQLi) and a 2,000-request/minute per-IP rate limit. Only clean traffic reaches the origin.

**3. Intake Lambda.** Validates the payload against a schema, computes a canonical SHA-256 hash, calls KMS to sign it with an RSA-4096 asymmetric key. The signature and hash are stored; the ciphertext goes to S3.

**4. Persistence.** DynamoDB holds the index (application_id, borrower_id, status, timestamps). S3 holds the raw ciphertext, encrypted with SSE-KMS using a per-object data key wrapped by the master key. Object Lock is COMPLIANCE mode, 7 years — undeletable, even by root.

**5. Attested enclave.** The credit pull runs inside a Nitro Enclave. The host machine cannot read the enclave's memory. Only a signed decision token escapes.

**6. Lender relay.** When a matched lender accepts the application, they receive the ciphertext plus a 2-of-3 decryption share. The borrower holds one share. The lender holds one. The third is escrowed in the enclave. Biteris itself holds none of them — it cannot read the application it just relayed.

**7. Decision signed and returned.** The lender's decision is signed with a second KMS key, written back to DynamoDB, and pushed to the borrower via WebSocket. The decision token carries the lender's signature; the borrower can verify it independently.

**8. Audit chain.** Every step above appends an entry to a hash-chained log: `entry_hash = sha256(prev_hash + timestamp + event + payload_hash)`. The chain is signed with a third KMS key. Tampering with any entry invalidates every subsequent hash.

**9. Disbursement.** Funds move via FedNow. Reference number and confirmation are written to the same chain.

At no point does Biteris hold both a plaintext payload and the key required to read it.

---

## What's in this repo

Terraform. Everything is code. Nothing is clicked together in the AWS console.
