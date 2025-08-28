# Staging Deployment: ECS Fargate + ALB (HTTP origin) + CloudFront (HTTPS) + CI/CD + Monitoring

This project deploys a **Dockerized Frontend (Node minimal)** and **Backend (Node minimal)** to **AWS ECS Fargate**, fronted by an **Application Load Balancer (ALB)** as origin and **CloudFront** for public **HTTPS**. **Basic Auth** is enforced by an **Nginx sidecar** container in the frontend task. CI/CD uses **GitHub Actions** with OIDC. Alerts via **CloudWatch Alarms** to **SNS** (CPU > 70%).

> **HTTPS-only** for users: Public access goes through **CloudFront** with HTTPS. The ALB Security Group only allows traffic **from CloudFront IP ranges**, preventing direct HTTP access to ALB from the internet.

## Repo Structure
(omitted to save space; see folders)
