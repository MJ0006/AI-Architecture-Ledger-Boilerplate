# Ledger Review Prompt

Use this before a new sprint or feature. Paste it into your AI tool, or say
"follow `.ai_ledger/review_prompt.md`".

---

Read `.ai_ledger/evolution_log.md` (and any `.ai_ledger/archive/*.md` files relevant to the
upcoming work). Do not change any code. Produce a report with these sections:

1. **Request vs Result mismatches:** list every entry where the result differed from the request.
   Group them by cause (unclear request, wrong assumption, missing context, technical limit, agent error). For each
   group, give the user one concrete tip for wording future requests.
2. **Recurring hurdles:** problems, workarounds, or files that keep coming up.
3. **Technical debt:** shortcuts, duplicated logic, or inconsistent patterns between entries,
   with the file paths involved.
4. **Concepts to learn:** the concepts that appear most often in the log, as a short study list.
5. **Suggested rule updates:** proposed additions to `.ai_ledger/agent_directives.md` that would
   have prevented the issues above. Propose them only. Do not edit the file.

Keep each section to short bullets that cite entry dates.

When the report is done, reset the review reminder by running `date +%s > .ai_ledger/last_review`
(or tell the user to run it if you cannot run commands).
