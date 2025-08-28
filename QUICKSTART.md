# QUICKSTART (5 pasos)

> Requisitos: Cuenta AWS; rol OIDC para GitHub (ver `docs/oidc_setup.md`); variables/secrets en el repo.

## 1) Variables/Secrets en GitHub
- Variables → Actions:
  - `AWS_REGION` = `us-east-1` (o tu región)
  - `ECR_REPO_FE` = `staging-frontend`
  - `ECR_REPO_BE` = `staging-backend`
- Secrets → Actions:
  - `AWS_ACCOUNT_ID` = `<tu-cuenta-12-dígitos>`

## 2) Rol OIDC en AWS
Sigue `docs/oidc_setup.md` para crear el rol `staging-github-oidc` y (si falta) el OIDC provider.

## 3) Primer despliegue (push a main)
```bash
git add -A
git commit -m "chore: initial deploy"
git push origin main
```
El launcher `.github/workflows/deploy.yml` invoca `cicd/deploy.yml`: Terraform → ECR login → build & push → re-apply.

## 4) Acceso público (HTTPS + Basic Auth)
- Copia el output `cloudfront_domain_name` (en logs o local con `terraform output`).
- Abre `https://<cloudfront_domain_name>/` → ingresa con:
  - usuario: `staging`, password: `staging` (valores por defecto en SSM).

## 5) Verificación y monitoreo
- API: `https://<cloudfront_domain_name>/api/health` → `{ "status": "ok" }`
- E2E manual (Actions → **E2E Tests (manual)**):
  - `base_url`: `https://<cloudfront_domain_name>`
  - usuario/pass: `staging` / `staging`
- Alarma CPU (>70%): ejecuta `scripts/spike_cpu_task.sh` y espera ~10 min. Confirma el email de SNS.
