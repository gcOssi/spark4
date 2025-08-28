# Troubleshooting Guide

This guide covers common issues when deploying the staging environment.

---

## 1. GitHub Actions fails with `AccessDenied` or `AssumeRole` errors
- Ensure the IAM Role `staging-github-oidc` exists and trust policy matches your repo/branch.
- Verify `AWS_ACCOUNT_ID` secret is set correctly in GitHub.
- Check OIDC provider `token.actions.githubusercontent.com` exists in AWS account.

**Fix:** Re-run `docs/oidc_setup.md` step 1 & 2.

---

## 2. Terraform Apply fails with `Throttling` or `ResourceInUse`
- AWS API rate limits can cause transient errors.
- **Fix:** Re-run the workflow; Terraform is idempotent.

---

## 3. ECS Service stuck in `PROVISIONING` or `DRAINING`
- Check CloudWatch Logs for `frontend`, `backend`, and `auth-proxy` containers.
- Ensure images were built & pushed (`ECR` repos contain `:latest` tags).
- If container fails health check, ALB will cycle tasks.

**Fix:** Run locally with `docker-compose up` to validate images.

---

## 4. ALB returns `503 Service Unavailable`
- Target groups may have no healthy tasks.
- Check ECS tasks → Logs.
- Ensure security groups allow ALB → ECS traffic.

---

## 5. CloudFront returns `502 Bad Gateway`
- CloudFront is HTTPS, but forwards to ALB HTTP.
- If ALB is not healthy or listener not serving, CloudFront returns 502.

**Fix:** Check ALB target groups in AWS console.

---

## 6. Basic Auth not prompting
- Confirm Nginx sidecar container is running.
- Check `frontend/nginx.conf`.
- Ensure `BASIC_AUTH_USER` / `BASIC_AUTH_PASS` are set (SSM defaults to `staging/staging`).

---

## 7. CloudWatch Alarms not triggering
- Alarms require sustained >70% CPU over 2 periods (10 minutes total).
- Ensure spike task script is run and tasks visible in ECS console.

**Fix:** Run `scripts/spike_cpu_task.sh` and wait ~10 minutes.

---

## 8. Email Alerts not received
- SNS subscription requires confirmation via email link.
- **Fix:** Check your inbox for "AWS Notification - Subscription Confirmation". Confirm it.

---

## 9. Destroy stuck resources
```bash
cd infrastructure
terraform destroy -auto-approve
```
If resources remain, manually delete ECS services, ALB, and CloudFront in AWS console.

---

## 10. Cost Cleanup Reminder
- CloudFront, ALB, ECS, CloudWatch alarms, and ECR repos can generate costs if left running.
- **Always `terraform destroy` when finished testing.**
