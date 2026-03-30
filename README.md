
## 1. Solution Overview

This solution provides a centralized, scalable logging pipeline using **Grafana Loki** as the storage engine, backed by **Amazon S3**. It captures logs from three distinct sources:

1.  **EKS Clusters:** Via Fluent Bit DaemonSets.
    
2.  **EC2 Instances:** Via a native Fluent Bit installation.
    
3.  **ECS Fargate:** Via AWS Firelens (Fluent Bit sidecar).

4. **External Servers:** Via Fluent Bit installed on-premise or in other clouds, communicating over VPN or Secure Public Gateway.
    

----------

## 2. Required Inputs (Existing Infrastructure)

To deploy this Terraform code, you must provide the following existing resource details:


| **Input** | **Source / Variable**  | **Purpose** | 
|  --------  |  -------  | -------  |
|**EKS OIDC Provider ARN**|`module.eks.oidc_provider_arn`|Required to establish the trust relationship between AWS IAM and the EKS cluster.|
| **EKS OIDC Issuer URL** | `module.eks.cluster_oidc_issuer_url` | Used to generate the `sub` (subject) condition in the IAM Role for the Loki Service Account. |
| **Route 53 Private Zone** | `data.aws_route53_zone.internal` | The existing internal DNS zone where the `loki-internal.ematiq.com` CNAME will be created.|
| **VPC & Private Subnets** | `data.aws_vpc.selected` |The network boundary where EC2, ECS, and EKS reside; ensures private connectivity to Loki on port 3100. |
|**IAM Execution Role**|`aws_iam_role.ecs_execution_role`|Standard IAM role with `AmazonECSTaskExecutionRolePolicy` for Fargate image pulling and CloudWatch logging. |
|**AWS Account ID** | `data.aws_caller_identity.current.account_id` | Used as a suffix for the S3 bucket name to ensure global uniqueness and prevent naming collisions. |
| **VPN / Direct Connect**| Existing Network | Allows external servers to resolve and reach `loki-internal.ematiq.com`.|
| **Loki Tenant ID / Basic Auth** | Loki Configuration | Provides a layer of security for logs arriving from outside the AWS VPC.

----------

## 3. Component Deep Dive

### A. Identity Management (The IRSA Bridge)

Unlike standard IAM roles, Loki uses **IRSA**.

-   **The IAM Role:** Trusts the EKS OIDC provider.
    
-   **The Condition:** Only allows the service account `system:serviceaccount:logging:loki` to assume it.
    
-   **The Annotation:** The Kubernetes Service Account links the two, allowing Loki pods to inherit S3 permissions without needing secret keys.
    

### B. Storage Strategy (The S3 Backend)

Logs are stored in a bucket named `loki-storage-<ACCOUNT_ID>`.

-   **TSDB Indexing:** Uses the modern `v13` schema (ships with Loki 3.x/6.x) which is optimized for S3 performance.
    
-   **Retention:** A 30-day lifecycle policy is enforced at the S3 bucket level to control costs automatically.
    

### C. Ingestion Path (The Gateway)

The **Loki Gateway** (Nginx) acts as the single entry point.

-   It is exposed via an **Internal AWS Load Balancer**.
    
-   The Route 53 record `loki-internal.ematiq.com` points to this Load Balancer, ensuring that log traffic never leaves the private network.
    
### D. External Ingestion (Hybrid Cloud)

For servers outside AWS, the architecture mirrors the EC2 setup but requires a secure "front door."

-   **Connectivity:** External servers must have a route to the VPC (VPN) OR the **Loki Gateway** must be exposed via a **Public Network Load Balancer (NLB)**.
    
-   **Authentication:** Unlike IRSA (which is automatic), external servers should use **Basic Auth** or **Header-based Authentication** configured at the Nginx Gateway level to ensure only authorized logs are ingested.

----------

## 4. Log Flow Logic

1.  **Collection:** Fluent Bit (on EC2/ECS/EKS) scrapes logs (e.g., `/var/log/nginx/access.log`).
    
2.  **Enrichment:** Filters add metadata like `hostname`, `env`, and `job`.
    
3. **Transport:** 
	-   **Internal:** Logs sent to `http://loki-internal.ematiq.com:3100`.
	-   **External:** Logs sent via VPN to the internal endpoint or via a secure Public URL (e.g., `https://loki-external.ematiq.com`).

5.  **Ingestion:** The Loki `write` components receive the logs, chunk them, and upload them to S3.
    
6.  **Visualization:** Grafana queries the Loki `read` components, which pull the relevant chunks from S3.
    

----------

## 5. Known Constraints & Assumptions

-   **Binary Versioning:** The EC2 `user_data` assumes an Amazon Linux 2 environment.
    
-   **Network Latency:** Port `3100` must be open in the Security Groups of the EKS worker nodes (allowing traffic from the EC2 and ECS security groups).
    
-   **Global Uniqueness:** The S3 bucket name relies on the `aws_caller_identity` to prevent naming conflicts.

- **External Security:** This PoC assumes external servers are connected via VPN. If using the public internet, **TLS encryption (HTTPS)** and **Authentication** must be enabled on the Loki Gateway to prevent unauthorized data injection or interception.

----------

## 6. Possible Improvements

### What is Missing for "Production" (Beyond PoC)

While the PoC is solid, moving to 5TB/day in production would most likely require adding these three components:

1.  **Caching (Memcached/Redis):** To make queries for 5TB of data fast, we will eventually want to add a caching layer for the index and result sets.
    
2.  **Canary:** A tiny service that sends a "heartbeat" log every second to ensure there are no gaps in the 5TB stream.