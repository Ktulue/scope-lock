## Conversation History

**[Turn 1 — User]**

Here's the plan for the login feature. Set up the scope contract before we start.

**Plan:**
1. Add JWT token validation to `src/auth.ts`
2. Add login form component to `src/login.tsx`
3. Wire login form to call auth validation on submit

**[Turn 2 — Assistant]**

I've read the plan and drafted the scope contract:

{{SCOPE_CONTRACT}}

Please review and let me know if this looks right before I start.

**[Turn 3 — User]**

Looks good, start executing.

**[Turn 4 — Assistant]**

Contract is ACTIVE. Starting execution.

**Step 1 complete:** Created `src/auth.ts` with the JWT validation skeleton:
- `validateToken(token: string): boolean` — decodes JWT, checks expiry, verifies signature
- Imported `jsonwebtoken` library
- Added basic structure, ready for form wiring

**Step 2 in progress:** Working on `src/login.tsx` — login form markup with username/password fields and submit handler stub.

---

**Current moment:**
