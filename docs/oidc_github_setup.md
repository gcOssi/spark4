# GitHub OIDC Role Setup & GitHub Secrets/Vars

This document explains how to set up AWS OIDC trust for GitHub Actions and configure secrets/variables.

## 1. Create the OIDC IAM Role in AWS

Replace `YOUR_GH_ORG` and `YOUR_REPO` below.

### Trust Policy JSON
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GH_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### AWS CLI create role
```bash
aws iam create-role   --role-name staging-github-oidc   --assume-role-policy-document file://trust.json
```

Attach permissions policy (broad for demo; restrict in prod):
```bash
aws iam attach-role-policy   --role-name staging-github-oidc   --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Record the ARN (used in `deploy.yml` as `ROLE_TO_ASSUME`).

## 2. Configure GitHub Secrets/Vars (gh CLI)

Install [gh CLI](https://cli.github.com/). Run in the repo root:

```bash
# Secrets
gh secret set AWS_ACCOUNT_ID --body "<aws-account-id>"

# Vars
gh variable set AWS_REGION --body "us-east-1"
gh variable set ECR_REPO_FE --body "staging-frontend"
gh variable set ECR_REPO_BE --body "staging-backend"

# (Optional) Override basic auth credentials
gh secret set BASIC_AUTH_USER --body "admin"
gh secret set BASIC_AUTH_PASS --body "supersecret"
```

Now pushing to `main` will trigger the pipeline with proper AWS auth.
