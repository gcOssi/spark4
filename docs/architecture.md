# Architecture

```mermaid
flowchart LR
  user((User)) ---|HTTPS 443| CF[Amazon CloudFront]
  CF --- ALB[ALB (HTTP internal)]
  subgraph VPC[VPC (2 AZs)]
    direction TB
    subgraph Public[Public Subnets]
      ALB
    end
    subgraph Private[Private Subnets]
      direction LR
      FEsvc[ECS Svc: FE + Nginx]
      BEsvc[ECS Svc: Backend]
      FEsvc --> BEsvc
    end
  end
  ECR[(ECR Repos)] -. push/pull .- FEsvc
  ECR -. push/pull .- BEsvc
  CW[(CloudWatch)] -. metrics/alarms .- FEsvc
  CW -. metrics/alarms .- BEsvc
  SNS[(SNS Topic)] -. notifications .- CW
  GA[(GitHub Actions)] -. docker push .- ECR
  GA -. terraform apply .- ALB
```

## Notes
- Public access via **CloudFront HTTPS** (default cert).
- **Basic Auth** handled by **Nginx sidecar** in the FE task.
- **CPU alarms** at 70% to SNS.
