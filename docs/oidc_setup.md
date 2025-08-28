# GitHub OIDC → AWS (Copy‑Paste Guide)

This guide creates an AWS IAM Role that GitHub Actions can assume via **OpenID Connect (OIDC)**, and sets required **GitHub Actions Secrets/Variables** with `gh` CLI.

> **Replace placeholders**:
> - `AWS_ACCOUNT_ID` → your 12-digit account id
> - `AWS_REGION` → e.g., `us-east-1`
> - `GH_OWNER` → your GitHub org/user
> - `GH_REPO` → repository name
> - `BRANCH` → `main` (or another branch you deploy from)

---

## 0) Prereqs
- AWS CLI authenticated with permissions to manage IAM.
- `gh` CLI authenticated (`gh auth login`).

---

## 1) (One-time) Ensure GitHub OIDC Provider exists in the AWS account
If you already have `token.actions.githubusercontent.com` OIDC provider in this account, **skip** this step.

```bash
AWS_ACCOUNT_ID="<PUT_YOURS>"
aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[].Arn" --output text | grep -q token.actions.githubusercontent.com || \
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

> Thumbprint current as of GitHub docs; update if GitHub rotates its cert chain.

---

## 2) Create IAM Role for GitHub Actions (trusts OIDC + scoped to repo/branch)

```bash
AWS_ACCOUNT_ID="<PUT_YOURS>"
GH_OWNER="<org-or-user>"
GH_REPO="<repo-name>"
BRANCH="main"

ROLE_NAME="staging-github-oidc"
TRUST_POLICY_FILE="$(mktemp)"

cat > "$TRUST_POLICY_FILE" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GH_OWNER/GH_REPO:ref:refs/heads/BRANCH"
        }
      }
    }
  ]
}
JSON

# Inline replace placeholders in the trust policy
sed -i "s/AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" "$TRUST_POLICY_FILE"
sed -i "s/GH_OWNER/$GH_OWNER/g" "$TRUST_POLICY_FILE"
sed -i "s/GH_REPO/$GH_REPO/g" "$TRUST_POLICY_FILE"
sed -i "s/BRANCH/$BRANCH/g" "$TRUST_POLICY_FILE"

# Create role (idempotent-ish: ignore if exists)
aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1 || \
aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document "file://$TRUST_POLICY_FILE"

# Attach permissions (ECR/ECS/ELB/CloudWatch/SNS/SSM/Logs/CloudFront/ACM/EC2/S3/Route53)
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudFrontFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

> For production, consider a **least-privilege** custom policy instead of attaching broad managed policies.

Grab the role ARN:
```bash
aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text
```

---

## 3) Set GitHub Actions Secrets / Variables with `gh` CLI

```bash
GH_OWNER="<org-or-user>"
GH_REPO="<repo-name>"
AWS_ACCOUNT_ID="<PUT_YOURS>"
AWS_REGION="us-east-1"
ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/staging-github-oidc"

# Set variables (non-secret)
gh variable set AWS_REGION --repo "$GH_OWNER/$GH_REPO" --body "$AWS_REGION"
gh variable set ECR_REPO_FE --repo "$GH_OWNER/$GH_REPO" --body "staging-frontend"
gh variable set ECR_REPO_BE --repo "$GH_OWNER/$GH_REPO" --body "staging-backend"

# Set secrets
gh secret set AWS_ACCOUNT_ID --repo "$GH_OWNER/$GH_REPO" --body "$AWS_ACCOUNT_ID"

# Optional: override basic auth at deploy time (otherwise SSM defaults to staging/staging)
# gh secret set BASIC_AUTH_USER --repo "$GH_OWNER/$GH_REPO" --body "staging"
# gh secret set BASIC_AUTH_PASS --repo "$GH_OWNER/$GH_REPO" --body "staging"
```

> In the workflow we assume this role by ARN:
> `arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/staging-github-oidc`

---

## 4) Trigger a Deploy
- Commit & push to `main`:
```bash
git add -A && git commit -m "ci: initial deploy" && git push origin main
```
- Watch the workflow **Deploy Staging (ECS + Terraform)**.
- After success, fetch Terraform output `cloudfront_domain_name`:
  - In Actions logs, or run locally:
    ```bash
    cd infrastructure
    terraform output cloudfront_domain_name
    ```
